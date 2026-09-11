import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;

class ReceiveScreenArgs {
  final String coinSymbol;

  ReceiveScreenArgs({required this.coinSymbol});
}

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  var _showSubaddress = true;
  var _previousBrightness = 0.0;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_isMobile) _setBrightnessToMax();
  }

  @override
  void dispose() {
    if (_isMobile) _setBrightnessToNormal();
    super.dispose();
  }

  Future<void> _setBrightnessToMax() async {
    _previousBrightness = await ScreenBrightness().system;
    await ScreenBrightness().setApplicationScreenBrightness(1.0);
  }

  Future<void> _setBrightnessToNormal() async {
    await ScreenBrightness().setApplicationScreenBrightness(_previousBrightness);
  }

  void _copyAddress(String address) {
    final i18n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.addressCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as ReceiveScreenArgs?;
    final coinSymbol = args?.coinSymbol ?? 'XMR';
    final wallet = context.watch<WalletManager>().getWallet(coinSymbol);

    if (wallet == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(child: Text('Unknown coin: $coinSymbol', style: BrandText.body)),
        ),
      );
    }

    final primaryAddress = wallet.getPrimaryAddress();
    final receiveAddress = wallet.getReceiveAddress();
    final isDemoMode = wallet.connectionAddress == 'demo';

    // Monero-only subaddress UX. For non-Monero coins, fall back to primary.
    final monero = wallet is MoneroWallet ? wallet : null;
    final subSupported = monero?.serverSupportsSubaddresses;
    final unusedIndexSupported = monero?.unusedSubaddressIndexIsSupported;
    final canToggle = monero != null && subSupported == true && !isDemoMode;

    String? address;
    if (monero == null) {
      address = receiveAddress ?? primaryAddress;
    } else if (subSupported == false || isDemoMode) {
      address = primaryAddress;
    } else if (subSupported == true) {
      address = _showSubaddress ? receiveAddress : primaryAddress;
    }

    final showingSubaddress = canToggle && _showSubaddress;
    final ready = address != null;
    final warning = _warning(i18n, monero, subSupported, unusedIndexSupported);

    return ReceiveView(
      labels: ReceiveLabels(title: i18n.receiveTitle, copyAddress: i18n.receiveCopyAddress),
      onBack: () => Navigator.pop(context),
      onShare: _isMobile ? () => SharePlus.instance.share(ShareParams(text: address!)) : null,
      ready: ready,
      coinSymbol: wallet.coinSymbol,
      iconAsset: wallet.iconAsset,
      coinName: wallet.blockchainName,
      blockchainSubtitle: i18n.receiveBlockchainSubtitle(wallet.blockchainName),
      tabLabels: canToggle ? [i18n.receiveSubaddressTab, i18n.receivePrimaryTab] : null,
      selectedTab: _showSubaddress ? 0 : 1,
      onSelectTab: (i) => setState(() => _showSubaddress = i == 0),
      address: address ?? '',
      qrHeading: ready ? _heading(i18n, wallet, monero, showingSubaddress) : '',
      warning: warning,
      onCopy: () => _copyAddress(address!),
    );
  }

  String _heading(
    AppLocalizations i18n,
    CryptoWallet wallet,
    MoneroWallet? monero,
    bool showingSubaddress,
  ) {
    if (showingSubaddress) {
      final index = monero?.unusedSubaddressIndex;
      return index != null ? '${i18n.receiveSubaddressTab} #$index' : i18n.receiveSubaddressTab;
    }
    return i18n.receiveAddressHeading(wallet.blockchainName);
  }

  String? _warning(
    AppLocalizations i18n,
    MoneroWallet? monero,
    bool? subSupported,
    bool? unusedIndexSupported,
  ) {
    if (monero == null) return null;
    if (subSupported == false) return i18n.receiveServerNoSubaddressesWarn;
    if (subSupported == true && !_showSubaddress) return i18n.receivePrimaryAddressWarn;
    if (subSupported == true && _showSubaddress && unusedIndexSupported == false) {
      return i18n.receiveMaxSubaddressesReachedWarn;
    }
    return null;
  }
}
