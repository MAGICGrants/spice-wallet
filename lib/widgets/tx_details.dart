import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/amount_units.dart';
import 'package:spice_wallet/util/format.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart' show CryptoWallet, TxDetails, TxRecipient;
import 'package:wallet_infra/wallet_infra.dart' show SecureClipboard;

/// Read-only details for a single transaction, as a brand bottom sheet. Every
/// value is tappable to copy (SecureClipboard, so the clip is treated as
/// sensitive). Amounts/fee format per the [CryptoWallet]'s own decimals/symbols.
class TxDetailsDialog {
  static void show(BuildContext context, CryptoWallet wallet, TxDetails tx) {
    showBrandSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TxDetailsSheet(wallet: wallet, tx: tx),
    );
  }
}

class _TxDetailsSheet extends StatelessWidget {
  final CryptoWallet wallet;
  final TxDetails tx;

  const _TxDetailsSheet({required this.wallet, required this.tx});

  static const _labelStyle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: BrandColors.ink,
  );
  static const _valueStyle = TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 13,
    color: BrandColors.ink,
  );
  static const _mutedMono = TextStyle(
    fontFamily: 'Ubuntu Mono',
    fontSize: 12.5,
    color: BrandColors.inkMuted,
  );

  void _copy(BuildContext context, String text) {
    SecureClipboard.copy(text);
    final i18n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.copiedToClipboard)));
  }

  String _fmtAmount(BigInt units) => formatAmount(
    displayAmount(units, wallet.baseUnitDecimals),
    wallet.decimals,
    symbol: wallet.coinSymbol,
  );

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final incoming = tx.direction == consts.txDirectionIncoming;
    final date = DateTime.fromMillisecondsSinceEpoch(tx.timestamp * 1000);
    final feeText = formatAmount(
      displayAmount(tx.feeBaseUnits, wallet.feeBaseUnitDecimals),
      wallet.feeDecimals,
      symbol: wallet.feeCoinSymbol,
    );
    final heightText = NumberFormat('#,##0').format(tx.height == -1 ? 0 : tx.height);
    // Default (en) date symbols: initializeDateFormatting isn't wired.
    final dateText =
        '${DateFormat('HH:mm').format(date)} · ${DateFormat('d MMM yyyy').format(date)}';

    final recipients = tx.recipients.where((r) => !r.isChange).toList();
    final change = tx.recipients.where((r) => r.isChange).toList();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(i18n, incoming),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: _card(context, [
                    _row(context, i18n.amount, _fmtAmount(tx.amountBaseUnits), bold: true),
                    // The fee is only paid by the sender; received txs don't show it.
                    if (!incoming) _row(context, i18n.networkFee, feeText),
                    _row(
                      context,
                      i18n.txDetailsHashLabel,
                      shortenMiddle(tx.hash),
                      copyText: tx.hash,
                    ),
                    _row(context, i18n.txDetailsTimeAndDateLabel, dateText, mono: false),
                    _row(context, i18n.txDetailsConfirmationHeightLabel, heightText),
                    _row(context, i18n.txDetailsConfirmationsLabel, '${tx.confirmations}'),
                    if (tx.key.isNotEmpty)
                      _row(
                        context,
                        i18n.txDetailsViewKeyLabel,
                        shortenMiddle(tx.key, head: 6, tail: 4),
                        copyText: tx.key,
                      ),
                    if (recipients.isNotEmpty) _recipients(context, i18n, recipients),
                    for (final c in change)
                      _row(
                        context,
                        i18n.txDetailsChangeRecipientLabel,
                        shortenMiddle(c.address, head: 6, tail: 4),
                        copyText: c.address,
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              BrandButton.secondary(label: i18n.close, onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations i18n, bool incoming) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 40),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BrandColors.paper,
                    shape: BoxShape.circle,
                    border: Border.all(color: BrandColors.hairline, width: 1.5),
                  ),
                  child: Icon(
                    incoming ? Icons.south : Icons.north,
                    size: 11,
                    color: incoming ? BrandColors.success : BrandColors.cinnamon,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(i18n.txDetailsTitle, style: BrandText.sheetTitle),
              const SizedBox(height: 3),
              Text(
                '${incoming ? i18n.coinHomeReceived : i18n.coinHomeSent} · ${i18n.txDetailsCopyHint}',
                style: BrandText.caption.copyWith(fontSize: 12.5, color: BrandColors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, List<Widget> rows) {
    return BrandCard(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i != 0) Container(height: 1, color: BrandColors.hairline),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool mono = true,
    bool bold = false,
    String? copyText,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _copy(context, copyText ?? value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(label, style: _labelStyle),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: mono
                    ? _valueStyle.copyWith(
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                        fontSize: bold ? 15 : 13,
                      )
                    : const TextStyle(fontSize: 13, color: BrandColors.ink),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.copy_outlined, size: 15, color: BrandColors.inkFaint),
          ],
        ),
      ),
    );
  }

  Widget _recipients(BuildContext context, AppLocalizations i18n, List<TxRecipient> recipients) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(i18n.txDetailsRecipientsLabel, style: _labelStyle),
              const Spacer(),
              Text('${recipients.length}', style: _mutedMono),
            ],
          ),
          for (final r in recipients)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _copy(context, r.address),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(shortenMiddle(r.address, head: 6, tail: 4), style: _mutedMono),
                    ),
                    const SizedBox(width: 10),
                    Text(_fmtAmount(r.amountBaseUnits), style: _valueStyle),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy_outlined, size: 15, color: BrandColors.inkFaint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
