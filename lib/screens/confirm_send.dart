import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ui/wallet_ui.dart' as shared;

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/util/amount_units.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_infra/wallet_infra.dart' show RequestNotSentException;

class ConfirmSendScreenArgs {
  final String coinSymbol;
  final PendingTransaction tx;
  final String destinationAddress;
  final String? destinationOpenAlias;
  final String? destinationContactName;

  ConfirmSendScreenArgs({
    required this.coinSymbol,
    required this.tx,
    required this.destinationAddress,
    this.destinationOpenAlias,
    this.destinationContactName,
  });
}

/// Sentinel spliced into the high-fee warning so the shared view can bold the
/// percentage regardless of locale (the sentence itself contains spaces).
const _highFeeToken = '\u0000';
const _highFeeThreshold = 0.10;

/// Outcome of the confirm-send flow, so the caller can route and message each
/// case distinctly. [unresolved] is a broadcast whose reply was lost: the tx is
/// recorded and may be in the network, so it is terminal (route home) but must
/// not read as a clean "Sent!".
enum ConfirmSendResult { sent, unresolved, cancelled }

/// Presents the "Confirm Send" review as the shared brand bottom sheet. Builds
/// the display strings + high-fee flag from the wallet/tx + fiat rate, then
/// delegates to the shared [shared.showConfirmSendSheet] with `onConfirm` =
/// Spice's own `commitTx`. On an unresolved broadcast the confirm sheet closes
/// and a warning sheet is shown instead.
Future<ConfirmSendResult> showConfirmSendSheet(
  BuildContext context,
  ConfirmSendScreenArgs args,
) async {
  final i18n = AppLocalizations.of(context)!;
  final manager = Provider.of<WalletManager>(context, listen: false);
  final fiatRate = Provider.of<FiatRateModel>(context, listen: false);
  final wallet = manager.getWallet(args.coinSymbol);

  final decimals = wallet?.decimals ?? 12;
  final coinSymbol = wallet?.coinSymbol ?? args.coinSymbol;
  final feeDecimals = wallet?.feeDecimals ?? decimals;
  final feeSymbol = wallet?.feeCoinSymbol ?? coinSymbol;
  final feeIsForeign = wallet?.feeIsForeign ?? false;

  final amount = wallet == null
      ? 0.0
      : displayAmount(args.tx.amountBaseUnits, wallet.baseUnitDecimals);
  final fee = wallet == null
      ? 0.0
      : displayAmount(args.tx.feeBaseUnits, wallet.feeBaseUnitDecimals);

  final quote = fiatRate.quoteFor(coinSymbol);
  final coinRate = quote?.rate;
  final amountFiat = coinRate != null ? amount * coinRate : null;
  // The fee is in ETH for tokens; its fiat can't use the token's rate, so omit it.
  final networkFeeFiat = coinRate != null && !feeIsForeign ? fee * coinRate : null;

  final feeRatio = _feeToAmountRatio(fiatRate, wallet, args, amount, fee, feeIsForeign, feeSymbol);
  final showHighFeeWarning = feeRatio != null && feeRatio > _highFeeThreshold;

  // Set when the commit comes back unresolved; the confirm sheet still closes
  // normally, and the warning sheet is shown afterwards.
  var unresolved = false;
  // Set when the request never reached the server; the sheet closes (nothing was
  // sent) and the user lands back on the send form with the error toast shown.
  var connectionFailed = false;

  final committed = await shared.showConfirmSendSheet(
    context: context,
    labels: shared.ConfirmSendLabels(
      title: i18n.confirmSendTitle,
      description: i18n.confirmSendDescription,
      amount: i18n.amount,
      networkFee: i18n.networkFee,
      address: i18n.address,
      send: i18n.sendSendButton,
      cancel: i18n.cancel,
    ),
    coinSymbol: coinSymbol,
    iconAsset: wallet?.iconAsset ?? '',
    amountText: '${amount.toStringAsFixed(decimals)} $coinSymbol',
    amountFiat: amountFiat != null ? shared.formatFiat(amountFiat, quote!.currency) : null,
    feeText: '${fee.toStringAsFixed(feeDecimals)} $feeSymbol',
    feeFiat: networkFeeFiat != null ? shared.formatFiat(networkFeeFiat, quote!.currency) : null,
    address: args.destinationAddress,
    openAlias: args.destinationOpenAlias,
    contactName: args.destinationContactName,
    showHighFeeWarning: showHighFeeWarning,
    highFeeWarning: showHighFeeWarning ? i18n.confirmSendHighFeeWarning(_highFeeToken) : null,
    highFeeToken: _highFeeToken,
    highFeePercent: showHighFeeWarning ? '${(feeRatio * 100).round()}%' : null,
    onConfirm: () => _commitTx(
      context,
      args,
      onUnresolved: () => unresolved = true,
      onConnectionFailed: () => connectionFailed = true,
    ),
  );

  if (unresolved) {
    if (context.mounted) await _showUnresolvedSendSheet(context);
    return ConfirmSendResult.unresolved;
  }
  // Nothing was sent: the sheet is already closed, the toast is shown, and the
  // user stays on the send form to retry — not a success, so no navigation.
  if (connectionFailed) return ConfirmSendResult.cancelled;
  return committed == true ? ConfirmSendResult.sent : ConfirmSendResult.cancelled;
}

/// Commits the transaction. Surfaces its own errors as snackbars (matching the
/// prior behaviour) and rethrows so the shared sheet keeps itself open on
/// failure; on success it returns normally and the sheet pops `true`.
///
/// An unresolved broadcast is neither: it calls [onUnresolved] and returns
/// normally so the sheet closes, and the caller shows the warning sheet. It must
/// not be retried from the open sheet.
Future<void> _commitTx(
  BuildContext context,
  ConfirmSendScreenArgs args, {
  required VoidCallback onUnresolved,
  required VoidCallback onConnectionFailed,
}) async {
  final manager = Provider.of<WalletManager>(context, listen: false);
  final i18n = AppLocalizations.of(context)!;
  final wallet = manager.getWallet(args.coinSymbol);
  if (wallet == null) return;

  try {
    await wallet.commitTx(args.tx, args.destinationAddress);
  } on BroadcastFailure catch (failure) {
    if (failure.outcome == BroadcastOutcome.unknown) {
      // The bytes may be in the network and the tx is recorded as unresolved.
      // Close the sheet (return normally) and let the caller warn, rather than
      // claim success or leave a retry button that would build a second payment.
      onUnresolved();
      return;
    }
    // Rejected: nothing moved, so keep the sheet open to adjust and retry.
    if (context.mounted) shared.showBrandToast(context, i18n.unknownError);
    rethrow;
  } on RequestNotSentException {
    // Never reached the server (no connection / Tor circuit): nothing was sent.
    // Close the sheet and return to the form rather than leave it open.
    if (context.mounted) shared.showBrandToast(context, i18n.sendNoConnectionError);
    onConnectionFailed();
    return;
  } on FormatException catch (error) {
    var errorMsg = error.toString().replaceFirst('FormatException: ', '');
    if (error.toString().contains('HTTP error code 500')) {
      errorMsg = 'Failed to send transaction. You might have insufficient unlocked balance.';
    }
    if (context.mounted) {
      shared.showBrandToast(context, errorMsg);
    }
    rethrow;
  } catch (error) {
    log(LogLevel.error, error.toString());
    if (context.mounted) {
      shared.showBrandToast(context, i18n.unknownError);
    }
    rethrow;
  }
}

/// Warns that a send went out but was never confirmed, so it may or may not be in
/// the network. Single acknowledgement — there is nothing to retry here; the tx
/// is in history and the next sync settles it.
Future<void> _showUnresolvedSendSheet(BuildContext context) {
  final i18n = AppLocalizations.of(context)!;
  return shared.showBrandSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: shared.isDesktopModal ? EdgeInsets.zero : const EdgeInsets.fromLTRB(22, 8, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const shared.SheetHandle(),
            Row(
              children: [
                shared.SheetIcon(
                  icon: Icons.warning_rounded,
                  bg: shared.BrandColors.warningBg,
                  color: shared.BrandColors.warning,
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(i18n.warning, style: shared.BrandText.sheetTitle)),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              i18n.txDetailsUnknownStatus,
              style: shared.BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 18),
            shared.BrandButton(label: i18n.close, onPressed: () => Navigator.pop(sheetContext)),
          ],
        ),
      ),
    ),
  );
}

/// Fee as a fraction of the amount, or null when it can't be determined (token
/// send with no fiat rate). Same-currency fees compare directly; foreign
/// (token) fees compare in fiat.
double? _feeToAmountRatio(
  FiatRateModel fiatRate,
  CryptoWallet? wallet,
  ConfirmSendScreenArgs args,
  double amount,
  double fee,
  bool feeIsForeign,
  String feeSymbol,
) {
  if (amount <= 0) return null;
  if (!feeIsForeign) return fee / amount;

  final amountRate = fiatRate.rateFor(wallet?.coinSymbol ?? args.coinSymbol);
  final feeRate = fiatRate.rateFor(feeSymbol);
  if (amountRate == null || feeRate == null) return null;

  final amountFiat = amount * amountRate;
  if (amountFiat <= 0) return null;
  return (fee * feeRate) / amountFiat;
}
