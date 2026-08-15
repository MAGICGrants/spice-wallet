import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_service.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/wallet_core_glue.dart';
import 'package:wallet_domain/wallet_domain.dart' show WalletManager, CryptoWallet;

/// Android foreground service that keeps Monero (and other) wallets syncing
/// while the app is backgrounded — a persistent-notification alternative to the
/// budget-limited WorkManager task. Dies on force-quit (OS limitation).

const _channelId = 'spice_background_sync';
const _channelName = 'Background sync';

/// Entry point run inside the foreground-service isolate. Must be top-level.
@pragma('vm:entry-point')
void foregroundSyncCallback() {
  FlutterForegroundTask.setTaskHandler(_SyncTaskHandler());
}

class _SyncTaskHandler extends TaskHandler {
  WalletManager? _manager;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    installWalletCore();
    final manager = WalletManager(coins: buildCoins);
    _manager = manager;
    try {
      if (!await manager.hasAnyExistingWallet()) return;
      await manager.openAll();
      final wallets = manager.activeWallets;
      for (final w in wallets) {
        await w.loadPersistedConnection();
      }
      if (wallets.any((w) => w.usingTor)) {
        await TorService.sharedInstance.start();
        await TorService.sharedInstance.waitUntilConnected().timeout(
          const Duration(minutes: 2),
          onTimeout: () => log(LogLevel.warn, '[FG sync] Tor connection timed out'),
        );
      }
      // Connect each wallet; their own timers then drive the scan + checkpoints
      // for as long as this service keeps the isolate alive.
      for (final w in wallets) {
        if (w.connectionAddress.isEmpty) continue;
        try {
          await w.connectToDaemon();
        } catch (e) {
          log(LogLevel.warn, '[FG sync] connect failed: $e', coin: w.coinSymbol);
        }
      }
    } catch (e) {
      log(LogLevel.warn, '[FG sync] start failed: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final wallets = _manager?.activeWallets ?? const <CryptoWallet>[];
    final syncing = wallets.any(
      (w) => w.connectionAddress.isNotEmpty && !isWalletFullySynced(w),
    );
    FlutterForegroundTask.updateService(
      notificationTitle: 'Spice Wallet',
      notificationText: syncing ? 'Syncing…' : 'Wallet up to date',
    );

    // While this service runs it is the thing watching the chain, so it is the
    // thing that announces what it finds; the WorkManager task runs on its own
    // schedule and would otherwise never see these.
    final manager = _manager;
    if (manager != null) {
      unawaited(
        manager.notifyNewIncomingTxsAll().catchError((Object e) {
          log(LogLevel.warn, '[FG sync] notifying new transactions failed: $e');
        }),
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Checkpoint scan progress before tearing down, or everything scanned since
    // the last periodic store is lost.
    await _manager?.pauseSyncAndStoreAll();
    _manager?.dispose();
    _manager = null;
  }
}

/// Configures the service. Safe to call more than once.
void initForegroundSync() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: _channelId,
      channelName: _channelName,
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(30000),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

/// A wallet is fully caught up only once a real height has loaded: [isSynced]
/// can flip true in the post-open window before [syncedHeight] arrives (LWS
/// reports 0 first), which would otherwise show "up to date" prematurely.
bool isWalletFullySynced(CryptoWallet w) =>
    w.isConnected && w.isSynced && (w.syncedHeight ?? 0) > 0;

/// [synced] seeds the initial notification text so toggling the service on while
/// already caught up shows "up to date" immediately, not a stale "Syncing…"
/// until the first repeat tick.
Future<void> startForegroundSync({bool synced = false}) async {
  if (!Platform.isAndroid) return;
  initForegroundSync();
  await FlutterForegroundTask.requestNotificationPermission();
  if (await FlutterForegroundTask.isRunningService) return;
  await FlutterForegroundTask.startService(
    notificationTitle: 'Spice Wallet',
    notificationText: synced ? 'Wallet up to date' : 'Syncing…',
    callback: foregroundSyncCallback,
  );
}

Future<void> stopForegroundSync() async {
  if (!Platform.isAndroid) return;
  if (await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.stopService();
  }
}

/// Starts the service on launch if the user enabled it, so backgrounding keeps
/// syncing.
Future<void> startForegroundSyncIfEnabled() async {
  if (!Platform.isAndroid) return;
  final enabled =
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.foregroundSyncEnabled) ??
      false;
  if (enabled) await startForegroundSync();
}
