import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;

import 'package:spice_wallet/util/wallet.dart';

/// Opens v1's legacy `mywallet` file (the old polyseed-based Monero wallet) so
/// its seed can be revealed before the user deletes it. Read-only use; not
/// registered in the WalletManager. Dispose after use.
class LegacyMoneroWallet extends MoneroWallet {
  @override
  Future<String> resolveWalletPath() => getLegacyWalletPath();

  /// The wallet's seed phrase, available after [openExisting]: the 16-word
  /// polyseed when present, otherwise the 25-word legacy seed.
  Future<String?> seedPhrase() async {
    final polyseed = await readPolyseed();
    if (polyseed.isNotEmpty) return polyseed;
    final legacy = await readLegacySeed();
    return legacy.isNotEmpty ? legacy : null;
  }

  /// No-op: the legacy wallet's tx history is irrelevant here and the base
  /// implementation would write `xmr_*` prefs and hit the network.
  @override
  Future<void> loadTxHistory({bool persistCount = true}) async {}
}
