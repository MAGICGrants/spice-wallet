import 'package:spice_wallet/services/tor_service.dart';
import 'package:wallet_domain/wallet_domain.dart';

enum ConnectionIndicatorState { ok, loading, error }

/// Single source of truth for a wallet's connection indicator state, shared by
/// the coin-home header and the wallet-home coin rows.
ConnectionIndicatorState connectionIndicatorStateFor(CryptoWallet wallet) {
  if (wallet.connectionAddress.isEmpty) return ConnectionIndicatorState.error;
  if (wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) > 0) {
    return ConnectionIndicatorState.ok;
  }
  if (wallet.usingTor && TorService.sharedInstance.status == TorConnectionStatus.connecting ||
      !wallet.hasAttemptedConnection ||
      wallet.isConnected && !wallet.isSynced ||
      wallet.isConnected && wallet.isSynced && (wallet.syncedHeight ?? 0) == 0) {
    return ConnectionIndicatorState.loading;
  }
  return ConnectionIndicatorState.error;
}
