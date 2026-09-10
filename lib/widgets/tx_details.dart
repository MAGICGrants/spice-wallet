import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:wallet_domain/wallet_domain.dart' show CryptoWallet, TxDetails;
import 'package:wallet_ui/wallet_ui.dart' show TxDetailsSheetLabels, showTxDetailsSheet;

/// The tx-details popup is the shared brand bottom sheet in wallet-core
/// (`wallet_ui`), localization-agnostic. This adapter keeps Spice's call site
/// unchanged and supplies its translated strings (incl. the status banner).
class TxDetailsDialog {
  static void show(BuildContext context, CryptoWallet wallet, TxDetails tx) {
    final i18n = AppLocalizations.of(context)!;
    showTxDetailsSheet(
      context: context,
      wallet: wallet,
      tx: tx,
      labels: TxDetailsSheetLabels(
        title: i18n.txDetailsTitle,
        hash: i18n.txDetailsHashLabel,
        amount: i18n.amount,
        networkFee: i18n.networkFee,
        timeAndDate: i18n.txDetailsTimeAndDateLabel,
        confirmationHeight: i18n.txDetailsConfirmationHeightLabel,
        confirmations: i18n.txDetailsConfirmationsLabel,
        viewKey: i18n.txDetailsViewKeyLabel,
        recipients: i18n.txDetailsRecipientsLabel,
        changeRecipient: i18n.txDetailsChangeRecipientLabel,
        close: i18n.close,
        copied: i18n.copiedToClipboard,
        received: i18n.coinHomeReceived,
        sent: i18n.coinHomeSent,
        copyHint: i18n.txDetailsCopyHint,
        failed: i18n.txDetailsFailed,
        unknownStatus: i18n.txDetailsUnknownStatus,
        receivedAt: i18n.txDetailsReceivedAtLabel,
        unconfirmed: i18n.unconfirmed,
      ),
    );
  }
}
