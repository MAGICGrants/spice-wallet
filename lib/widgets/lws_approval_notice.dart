import 'package:flutter/widgets.dart';
import 'package:wallet_domain/wallet_domain.dart' show CryptoWallet;
import 'package:wallet_monero/wallet_monero.dart' show LwsPendingApproval, MoneroWallet;

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// The notice for a light-wallet server still waiting to approve this Monero
/// wallet, or null when nothing is pending (or [wallet] is not Monero).
Widget? lwsApprovalNotice(AppLocalizations i18n, CryptoWallet wallet) {
  if (wallet is! MoneroWallet) return null;
  return switch (wallet.lwsPendingApproval) {
    null => null,
    LwsPendingApproval.account => WarningCallout(i18n.lwsAwaitingApprovalAccount),
    LwsPendingApproval.restoreHeight => WarningCallout(i18n.lwsAwaitingApprovalRestoreHeight),
  };
}
