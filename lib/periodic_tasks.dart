import 'dart:io';

import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_service.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/wallet_core_glue.dart';
import 'package:wallet_domain/wallet_domain.dart' show WalletManager;
import 'package:workmanager/workmanager.dart';

class PeriodicTasks {
  static const txNotifier = 'txNotifier';

  /// iOS BGAppRefreshTask: opportunistic, ~30s, iOS decides when. Only light
  /// clearnet wallets can do anything useful in it.
  static const iosRefresh = 'refresh';

  /// iOS BGProcessingTask: minutes, while charging and idle — room for Tor to
  /// bootstrap. Still never a Monero node scan.
  static const iosProcessing = 'processing';
}

/// Identifiers must match BGTaskSchedulerPermittedIdentifiers in Info.plist and
/// the registrations in AppDelegate.
const _iosBundleId = 'org.magicgrants.spicewallet';
const _iosRefreshTaskId = '$_iosBundleId.${PeriodicTasks.iosRefresh}';
const _iosProcessingTaskId = '$_iosBundleId.${PeriodicTasks.iosProcessing}';

/// Max wall-clock we let a background run scan before returning, leaving margin
/// under Android's ~10-minute WorkManager budget to persist + notify.
const _backgroundSyncBudget = Duration(minutes: 9);

/// What an iOS BGAppRefreshTask gets is short and not negotiable; overrunning it
/// makes iOS schedule the next one less willingly.
const _iosRefreshBudget = Duration(seconds: 25);

/// How often a background run checks on the scan it is waiting for.
const _backgroundSyncPollInterval = Duration(seconds: 5);

/// Consecutive polls with no synced-height movement before a run gives up the
/// rest of its budget. Must outlast a refresh cycle: in LWS mode the height only
/// moves when the ~20s cycle reloads stats, so a shorter window reads a healthy
/// run as stuck.
const _backgroundSyncStuckPolls = 12;

/// One background pass. [budget] is the wall-clock it may use; [allowTor] and
/// [allowNode] say what the scheduling window can accommodate — a ~30s iOS
/// refresh can carry neither a Tor bootstrap nor a Monero node scan. They are
/// re-checked here, not trusted from the scheduler, because iOS can deliver a
/// task scheduled under a connection the user has since changed.
Future<bool> runTxNotifier({
  Duration budget = _backgroundSyncBudget,
  bool allowTor = true,
  bool allowNode = true,
}) async {
  installWalletCore();

  // Decide what this window can sync WITHOUT opening any wallet file: load the
  // persisted connections onto a probe manager and read their type/Tor. Opening
  // a coin's file — a Monero wallet especially — is the expensive part, and a
  // short iOS refresh must not pay it for coins it will skip.
  final probe = WalletManager(coins: buildCoins);
  if (!await probe.hasAnyExistingWallet()) return true;
  await probe.loadCachedDisplayState();

  // Scheduling-window policy: the short iOS refresh takes neither Tor (a
  // bootstrap can outlast the window) nor a Monero node (a scan can't finish);
  // the charging processing window allows Tor but still never a node. BTC/ETH
  // use light servers — never 'node' — so they always qualify.
  final syncableSymbols = probe.allWallets
      .where(
        (w) =>
            w.connectionAddress.isNotEmpty &&
            (allowNode || w.connectionType != 'node') &&
            (allowTor || !w.usingTor),
      )
      .map((w) => w.coinSymbol)
      .toSet();
  probe.dispose();
  if (syncableSymbols.isEmpty) return true;

  // Open ONLY the syncable coins — a filtered registry, so no other coin's file
  // (or native scan thread) is touched.
  final walletManager = WalletManager(
    coins: () => buildCoins().where((w) => syncableSymbols.contains(w.coinSymbol)).toList(),
  );
  await walletManager.openAll();

  final wallets = walletManager.activeWallets;
  if (wallets.isEmpty) return true;

  for (final w in wallets) {
    await w.loadPersistedConnection();
  }

  if (wallets.any((w) => w.usingTor)) {
    await TorService.sharedInstance.start();
    await TorService.sharedInstance.waitUntilConnected().timeout(
      Duration(minutes: 2),
      onTimeout: () => log(LogLevel.warn, '[Background sync] Tor connection timed out'),
    );
  }

  // Kick each wallet's daemon connection (starts the scan thread).
  await Future.wait(
    wallets.map((w) async {
      if (w.connectionAddress.isEmpty) return;
      try {
        await w.connectToDaemon();
      } catch (e) {
        log(LogLevel.warn, '[Background sync] connect failed: $e', coin: w.coinSymbol);
      }
    }),
  );

  // Keep the isolate alive so the on-device scan keeps advancing, up to the
  // window's budget. The wallets' own timers drive the refresh; we just wait,
  // and stop early once everything's synced or once no wallet is getting
  // anywhere (unreachable server, dead Tor circuit, stalled scan) — holding the
  // wake-up open for the rest of the budget then just spends battery.
  final deadline = DateTime.now().add(budget);
  var lastHeights = {for (final w in wallets) w.coinSymbol: w.syncedHeight};
  var stuckPolls = 0;
  while (DateTime.now().isBefore(deadline)) {
    final allDone = wallets.every(
      (w) => w.connectionAddress.isEmpty || (w.isConnected && w.isSynced),
    );
    if (allDone) break;

    final progressed = wallets.any((w) => w.syncedHeight != lastHeights[w.coinSymbol]);
    if (progressed) {
      lastHeights = {for (final w in wallets) w.coinSymbol: w.syncedHeight};
      stuckPolls = 0;
    } else if (++stuckPolls >= _backgroundSyncStuckPolls) {
      log(LogLevel.warn, '[Background sync] no scan progress; ending run early.');
      break;
    }

    await Future.delayed(_backgroundSyncPollInterval);
  }

  for (final w in wallets) {
    if (w.connectionAddress.isEmpty) continue;
    try {
      await w.loadTxHistory(persistCount: false);
    } catch (e) {
      log(LogLevel.warn, '[Background sync] loadTxHistory failed: $e', coin: w.coinSymbol);
    }
  }

  // Checkpoint the scan so a killed isolate doesn't lose progress since the last
  // store, then announce new incoming txs. The glue's notifier respects the
  // notifications toggle on mobile and records txs as seen either way, so
  // enabling notifications later does not replay a backlog.
  await walletManager.pauseSyncAndStoreAll();
  await walletManager.notifyNewIncomingTxsAll();

  return true;
}

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      // ~30s, whenever iOS feels like it: enough for a light server to report
      // what it already scanned, and nothing more.
      case PeriodicTasks.iosRefresh:
        return runTxNotifier(budget: _iosRefreshBudget, allowTor: false, allowNode: false);

      // Charging and idle, so there is room for Tor to bootstrap first.
      case PeriodicTasks.iosProcessing:
        return runTxNotifier(allowNode: false);

      case PeriodicTasks.txNotifier:
      default:
        // A node scan is heavy, so only run it when Background Sync is on; light
        // coins (LWS/Electrum/RPC) still notify on the Notifications toggle
        // alone. Node-mode notifications and Background Sync are the same work.
        final backgroundSync =
            await SharedPreferencesService.get<bool>(
              SharedPreferencesKeys.backgroundSyncEnabled,
            ) ??
            false;
        return runTxNotifier(allowNode: backgroundSync);
    }
  });
}

/// WorkManager's minimum periodic interval.
const _minSyncIntervalMinutes = 15;

/// (Re)registers background work to match the current settings, or cancels it.
/// Call after anything that changes the answer: the notifications toggle, the
/// background-sync toggle, or a connection change.
Future<void> applyBackgroundTaskRegistration() async {
  if (Platform.isIOS) return _applyIosBackgroundTasks();
  if (!Platform.isAndroid) return;

  final backgroundSync =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.backgroundSyncEnabled) ??
      false;
  final notifications =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ?? false;

  await Workmanager().cancelByUniqueName(PeriodicTasks.txNotifier);
  if (!backgroundSync && !notifications) return;

  final minutes =
      await SharedPreferencesService.get<int>(
        SharedPreferencesKeys.backgroundSyncIntervalMinutes,
      ) ??
      _minSyncIntervalMinutes;

  // A background scan is heavy (a Monero node in particular), so when
  // background sync is on gate it on charging + WiFi; a notifications-only run
  // is light and takes the looser constraint.
  final constraints = backgroundSync
      ? Constraints(networkType: NetworkType.unmetered, requiresCharging: true)
      : Constraints(networkType: NetworkType.connected, requiresBatteryNotLow: true);

  await Workmanager().registerPeriodicTask(
    PeriodicTasks.txNotifier,
    "Background sync",
    frequency: Duration(
      minutes: minutes < _minSyncIntervalMinutes ? _minSyncIntervalMinutes : minutes,
    ),
    constraints: constraints,
  );
}

/// iOS scheduling. Gated on the notifications toggle — the two windows exist to
/// deliver incoming-tx notifications, not to advance a heavy scan. Which coins
/// each window actually syncs is decided per-run in [runTxNotifier]: the short
/// refresh takes light clearnet wallets (XMR-LWS, BTC, ETH); the charging
/// processing window additionally allows Tor. A Monero node is never
/// background-scanned on iOS. Both tasks are still registered when notifications
/// are on; a window with nothing to sync simply returns early.
Future<void> _applyIosBackgroundTasks() async {
  final notifications =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled) ?? false;

  await Workmanager().cancelByUniqueName(_iosRefreshTaskId);
  await Workmanager().cancelByUniqueName(_iosProcessingTaskId);

  if (!notifications) return;

  await Workmanager().registerPeriodicTask(
    _iosRefreshTaskId,
    PeriodicTasks.iosRefresh,
    frequency: Duration(minutes: _minSyncIntervalMinutes),
  );
  await Workmanager().registerProcessingTask(
    _iosProcessingTaskId,
    PeriodicTasks.iosProcessing,
    constraints: Constraints(networkType: NetworkType.connected, requiresCharging: true),
  );
}

Future<void> registerPeriodicTasks() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return;
  }

  Workmanager().initialize(_callbackDispatcher);
  await applyBackgroundTaskRegistration();
}
