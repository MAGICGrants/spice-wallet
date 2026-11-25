import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/l10n/shared_strings.dart';
import 'package:spice_wallet/screens/receive_address.dart' show openReceiveAddress;
import 'package:wallet_domain/wallet_domain.dart' show AddressLabelModel, CryptoWallet, TxDetails;
import 'package:wallet_ui/wallet_ui.dart' show TxDetailsSheetLabels, showTxDetailsSheet;

/// The tx-details popup is the shared brand bottom sheet in wallet-core
/// (`wallet_ui`), localization-agnostic. This adapter keeps Spice's call site
/// unchanged and supplies its translated strings (incl. the status banner),
/// and the labels the user gave the wallet's own addresses, each of which
/// opens that address's screen.
class TxDetailsDialog {
  static void show(BuildContext context, CryptoWallet wallet, TxDetails tx) {
    final i18n = AppLocalizations.of(context)!;
    final labels = context.read<AddressLabelModel>();
    showTxDetailsSheet(
      context: context,
      wallet: wallet,
      tx: tx,
      addressLabel: (address) => labels.labelFor(wallet.coinSymbol, address),
      onOpenAddress: wallet.rotatingAddressKind == null
          ? null
          : (address) => openReceiveAddress(context, wallet, address),
      labels: TxDetailsSheetLabels(
        title: i18n.shared.txDetailsTitle,
        hash: i18n.shared.txDetailsHashLabel,
        amount: i18n.shared.amount,
        networkFee: i18n.shared.networkFee,
        timeAndDate: i18n.shared.txDetailsTimeAndDateLabel,
        confirmationHeight: i18n.shared.txDetailsConfirmationHeightLabel,
        confirmations: i18n.shared.txDetailsConfirmationsLabel,
        viewKey: i18n.shared.txDetailsViewKeyLabel,
        recipients: i18n.shared.txDetailsRecipientsLabel,
        changeRecipient: i18n.shared.txDetailsChangeRecipientLabel,
        close: i18n.shared.close,
        copied: i18n.shared.copiedToClipboard,
        received: i18n.shared.coinHomeReceived,
        sent: i18n.shared.coinHomeSent,
        copyHint: i18n.shared.txDetailsCopyHint,
        failed: i18n.shared.txDetailsFailed,
        unknownStatus: i18n.shared.txDetailsUnknownStatus,
        receivedAt: i18n.shared.txDetailsReceivedAtLabel,
        unconfirmed: i18n.shared.unconfirmed,
      ),
    );
  }
}
