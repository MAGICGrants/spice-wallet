import 'dart:io';

import 'package:provider/provider.dart';

import 'package:spice_wallet/services/notifications_service.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/util/logging.dart';

import 'package:wallet_infra/wallet_infra.dart' as wcore;
import 'package:wallet_domain/wallet_domain.dart'
    show WalletAppConfig, WalletManager, CryptoWallet, baseUnitsToDecimalString;
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;
import 'package:wallet_bitcoin/wallet_bitcoin.dart' show BitcoinWallet, BitcoinTestnetWallet;
import 'package:wallet_ethereum/wallet_ethereum.dart'
    show EthereumWallet, EthereumSepoliaWallet, DaiWallet, DaiSepoliaWallet;
import 'package:wallet_openalias/wallet_openalias.dart' show resolveOpenAlias;

bool get _isMobile => Platform.isAndroid || Platform.isIOS;

/// baseUnitDecimals per coin, for formatting incoming-tx notification amounts.
/// The notifier only receives a `coinSymbol`, not the wallet, so the magnitudes
/// are listed here rather than read off each `CryptoWallet`.
const _baseUnitDecimals = <String, int>{
  'XMR': 12,
  'BTC': 8,
  'TBTC': 8,
  'ETH': 18,
  'SETH': 18,
  'DAI': 18,
  'SDAI': 18,
};

/// The coins spice registers. A fresh list each call — [WalletManager] and each
/// background isolate own their own instances.
List<CryptoWallet> buildCoins() => [
  MoneroWallet(),
  BitcoinWallet(),
  BitcoinTestnetWallet(),
  EthereumWallet(),
  EthereumSepoliaWallet(),
  DaiWallet(),
  DaiSepoliaWallet(),
];

bool _walletCoreInstalled = false;

/// Installs wallet-core's app config + injectable seams. Idempotent: main()
/// calls it, and each background isolate calls it too (a fresh isolate does not
/// inherit the main one's statics).
void installWalletCore() {
  if (_walletCoreInstalled) return;
  _walletCoreInstalled = true;

  WalletAppConfig.install(WalletAppConfig.spice);
  CryptoWallet.aliasResolver = resolveOpenAlias;

  wcore.NotificationService.windowsAppName = 'Spice Wallet';
  wcore.NotificationService.windowsAppUserModelId = 'org.magicgrants.spice';
  wcore.NotificationService.windowsGuid = '6dcf17a9-fb5f-4f47-b0b9-6d655e90adbf';

  wcore.WalletLog.sink = const _SpiceLogSink();
  wcore.WalletLog.isVerbose = () async =>
      await SharedPreferencesService.get<bool>(SharedPreferencesKeys.verboseLoggingEnabled) ??
      false;

  CryptoWallet.incomingTxNotifier = (tx, coinSymbol) {
    final decimals = _baseUnitDecimals[coinSymbol] ?? 0;
    final amount = double.tryParse(baseUnitsToDecimalString(tx.amountBaseUnits, decimals)) ?? 0;
    void show() => NotificationService().showIncomingTxNotification(
      title: 'Incoming transaction',
      body: 'You received $amount $coinSymbol',
    );
    if (!_isMobile) {
      // Desktop has no notifications toggle (Android/iOS-only), so it always
      // shows an incoming-tx notification.
      show();
      return;
    }
    // Mobile respects the toggle.
    SharedPreferencesService.get<bool>(SharedPreferencesKeys.notificationsEnabled).then((on) {
      if (on ?? false) show();
    });
  };
}

/// The wallet-core [WalletManager] provider.
ChangeNotifierProvider<WalletManager> walletManagerProvider() =>
    ChangeNotifierProvider(create: (_) => WalletManager(coins: buildCoins));

/// Routes wallet-core log lines into spice's logger.
class _SpiceLogSink extends wcore.LogSink {
  const _SpiceLogSink();

  @override
  Future<void> write(wcore.LogLevel level, String line) => log(switch (level) {
    wcore.LogLevel.info => LogLevel.info,
    wcore.LogLevel.warn => LogLevel.warn,
    wcore.LogLevel.error => LogLevel.error,
  }, line);
}
