import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_domain/wallet_domain.dart';

import 'package:spice_wallet/wallet_core_glue.dart';

/// Guards spice's wallet-core wiring: the full coin registry and the on-disk
/// naming that must never migrate (`xmr_`-prefixed prefs, `mywallet_<coin>`
/// files). See wallet-core docs/decisions.md D6.
void main() {
  setUp(() => WalletAppConfig.install(WalletAppConfig.spice));
  tearDown(WalletAppConfig.resetForTesting);

  test('registers all seven coins', () {
    final symbols = buildCoins().map((c) => c.coinSymbol).toSet();
    expect(symbols, {'XMR', 'BTC', 'TBTC', 'ETH', 'SETH', 'DAI', 'SDAI'});
  });

  test('keeps xmr_-prefixed pref keys and mywallet_<coin> files (no migration)', () {
    final config = WalletAppConfig.spice;
    expect(config.prefKeyNamer('XMR', 'walletRestoreHeight'), 'xmr_walletRestoreHeight');
    expect(config.walletFileNamer('XMR'), 'mywallet_xmr');
    expect(config.walletFileNamer('BTC'), 'mywallet_btc');
  });
}
