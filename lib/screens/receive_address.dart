import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/l10n/shared_strings.dart';
import 'package:spice_wallet/screens/desktop/home_shell.dart';
import 'package:spice_wallet/screens/history.dart' show HistoryScreenArgs;
import 'package:spice_wallet/screens/receive.dart' show shareAddress;
import 'package:spice_wallet/util/labeled_addresses.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/util/qr_brightness.dart';
import 'package:spice_wallet/util/secure_clipboard.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class ReceiveAddressArgs {
  final String coinSymbol;

  /// The address as the screen that opened it listed it. The screen keeps its
  /// totals current from the wallet's history, and shows these until then.
  final UsedReceiveAddress used;

  /// The desktop back link's label: where Back returns to. Null: just "Back".
  final String? backLabel;

  ReceiveAddressArgs({required this.coinSymbol, required this.used, this.backLabel});
}

/// Opens the screen of [address], one of [wallet]'s used receive addresses: from
/// a label in the transaction details, which knows only the address. Does
/// nothing when it is not among them.
Future<void> openReceiveAddress(BuildContext context, CryptoWallet wallet, String address) async {
  final used = await usedReceiveAddresses(wallet);
  if (!context.mounted) return;
  final match = used.where((u) => u.address == address).firstOrNull;
  if (match == null) return;
  Navigator.pushNamed(
    context,
    '/receive_address',
    arguments: ReceiveAddressArgs(coinSymbol: wallet.coinSymbol, used: match),
  );
}

/// One used receive address: its QR, to hand it out again, what it received,
/// its label, and the way to its transactions.
class ReceiveAddressScreen extends StatefulWidget {
  const ReceiveAddressScreen({super.key});

  @override
  State<ReceiveAddressScreen> createState() => _ReceiveAddressScreenState();
}

class _ReceiveAddressScreenState extends State<ReceiveAddressScreen> with QrBrightness {
  ReceiveAddressArgs? _args;
  bool _argsLoaded = false;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    _args = ModalRoute.of(context)?.settings.arguments as ReceiveAddressArgs?;
  }

  void _copy(String address) {
    final i18n = AppLocalizations.of(context)!;
    SecureClipboard.copy(address);
    showCopyToast(context, i18n.shared.addressCopied);
  }

  void _openTransactions(String coinSymbol, String address, String title) => Navigator.pushNamed(
    context,
    '/history',
    arguments: HistoryScreenArgs(coinSymbol: coinSymbol, address: address, backLabel: title),
  );

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final manager = context.watch<WalletManager>();
    final labels = context.watch<AddressLabelModel>();
    final args = _args;
    final wallet = args == null ? null : manager.getWallet(args.coinSymbol);
    final coin = wallet == null ? null : labeledAddressCoinOf(wallet);
    if (args == null || wallet == null || coin == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(
            child: Text('Unknown coin: ${args?.coinSymbol ?? ''}', style: BrandText.body),
          ),
        ),
      );
    }

    // Re-read as the history moves, so a payment that lands while this is open
    // shows in its totals; the opener's copy until the first read.
    return FutureBuilder(
      future: usedReceiveAddresses(wallet),
      builder: (context, snapshot) {
        final used =
            snapshot.data?.where((u) => u.address == args.used.address).firstOrNull ?? args.used;
        final label = labels.labelFor(coin.coinSymbol, used.address);
        final title = label ?? labeledAddressName(i18n.shared, coin.kind, used.index);

        AddressDetailContent content(double viewportHeight, {required bool wide}) =>
            AddressDetailContent(
              strings: i18n.shared,
              coin: coin,
              entry: (used: used, label: label),
              onCopy: () => _copy(used.address),
              onTransactions: () => _openTransactions(coin.coinSymbol, used.address, title),
              onEditLabel: () => editAddressLabel(context, coin, used),
              viewportHeight: viewportHeight,
              wide: wide,
              // Phones only, as on Receive: the hint promises a brighter
              // screen, and brightness is only managed on phones.
              qrEnlarged: qrEnlarged,
              onToggleQr: !wide && _isMobile ? toggleQr : null,
            );

        if (isDesktop) {
          return DesktopShell(
            active: DesktopNav.home,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(44, 30, 44, 36),
              children: [
                DesktopBackLink(
                  label: args.backLabel ?? i18n.shared.back,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
                Text(title, style: desktopTitleStyle),
                const SizedBox(height: 24),
                // The QR never enlarges here, so no viewport caps it.
                content(double.infinity, wide: true),
              ],
            ),
          );
        }

        return AddressDetailView(
          title: title,
          onBack: () => Navigator.pop(context),
          onShare: _isMobile ? (origin) => shareAddress(context, used.address, origin) : null,
          body: (viewportHeight) => content(viewportHeight, wide: false),
        );
      },
    );
  }
}
