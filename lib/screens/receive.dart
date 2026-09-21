import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/screens/desktop/home_shell.dart';
import 'package:spice_wallet/screens/desktop/receive_view.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/util/secure_clipboard.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;

class ReceiveScreenArgs {
  final String coinSymbol;

  /// When true (entered from the multicoin home), the coin card becomes an asset
  /// dropdown so the user can pick which chain to receive on.
  final bool allAssets;

  ReceiveScreenArgs({required this.coinSymbol, this.allAssets = false});
}

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  var _showSubaddress = true;
  var _previousBrightness = 0.0;

  String _coinSymbol = 'XMR';
  bool _allAssets = false;
  bool _argsLoaded = false;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_isMobile) _setBrightnessToMax();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments as ReceiveScreenArgs?;
    if (args != null) {
      _coinSymbol = args.coinSymbol;
      _allAssets = args.allAssets;
    }
  }

  void _selectAsset(String coinSymbol) {
    if (coinSymbol == _coinSymbol) return;
    setState(() {
      _coinSymbol = coinSymbol;
      _showSubaddress = true; // reset the Monero subaddress/primary tab
    });
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
    SecureClipboard.copy(address);
    showCopyToast(context, i18n.addressCopied);
  }

  /// Opens the system share sheet on [address], anchored at [origin].
  ///
  /// [origin] is the share button's rect. iOS presents the sheet as a popover
  /// pointing at it and share_plus rejects the call without one, so dropping it
  /// left the button doing nothing at all. Awaited and caught for the same
  /// reason: a fire-and-forget share turns every failure into silence.
  Future<void> _share(String address, Rect? origin) async {
    final i18n = AppLocalizations.of(context)!;
    final toast = BrandToast.of(context);
    try {
      await SharePlus.instance.share(ShareParams(text: address, sharePositionOrigin: origin));
    } catch (error) {
      log(LogLevel.error, 'Address share failed (origin=${origin ?? 'none'}): $error');
      toast.show(i18n.receiveShareError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final manager = context.watch<WalletManager>();
    final wallet = manager.getWallet(_coinSymbol);

    if (wallet == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(child: Text('Unknown coin: $_coinSymbol', style: BrandText.body)),
        ),
      );
    }

    final assetOptions = _allAssets
        ? [
            for (final w in receivableChains(manager))
              (coinSymbol: w.coinSymbol, iconAsset: w.iconAsset, coinName: w.blockchainName),
          ]
        : const <ReceiveAssetOption>[];

    final primaryAddress = wallet.getPrimaryAddress();
    final receiveAddress = wallet.getReceiveAddress();
    final isDemoMode = wallet.connectionAddress == 'demo';

    // Monero-only subaddress UX. For non-Monero coins, fall back to primary.
    final monero = wallet is MoneroWallet ? wallet : null;
    final subSupported = monero?.serverSupportsSubaddresses;
    final unusedIndexSupported = monero?.unusedSubaddressIndexIsSupported;
    final canToggle = monero != null && subSupported == true && !isDemoMode;
    // The address and the index that labels it, as one value: read separately
    // they can name different subaddresses.
    final sub = isDemoMode ? null : monero?.unusedSubaddress;

    String? address;
    if (monero == null) {
      address = receiveAddress ?? primaryAddress;
    } else if (subSupported == false || isDemoMode) {
      address = primaryAddress;
    } else if (subSupported == true) {
      address = _showSubaddress ? sub?.address : primaryAddress;
    }

    final showingSubaddress = canToggle && _showSubaddress;
    final ready = address != null;
    final warning = _warning(i18n, monero, subSupported, unusedIndexSupported);

    if (isDesktop) {
      return DesktopShell(
        active: DesktopNav.home,
        child: DesktopReceiveView(
          title: i18n.receiveTitle,
          copyLabel: i18n.receiveCopyAddress,
          qrHint: i18n.receiveQrHint(wallet.blockchainName),
          coinSymbol: wallet.coinSymbol,
          iconAsset: wallet.iconAsset,
          coinName: wallet.blockchainName,
          blockchainSubtitle: i18n.receiveBlockchainSubtitle(wallet.blockchainName),
          ready: ready,
          address: address ?? '',
          qrHeading: ready ? _heading(i18n, wallet, sub, showingSubaddress) : '',
          tabLabels: canToggle ? [i18n.receiveSubaddressTab, i18n.receivePrimaryTab] : null,
          selectedTab: _showSubaddress ? 0 : 1,
          onSelectTab: (i) => setState(() => _showSubaddress = i == 0),
          warning: warning,
          onCopy: () => _copyAddress(address!),
          onBack: () => Navigator.pop(context),
          assetOptions: assetOptions,
          onSelectAsset: _allAssets ? _selectAsset : null,
        ),
      );
    }

    return ReceiveView(
      labels: ReceiveLabels(title: i18n.receiveTitle, copyAddress: i18n.receiveCopyAddress),
      onBack: () => Navigator.pop(context),
      onShare: _isMobile ? (origin) => _share(address!, origin) : null,
      ready: ready,
      coinSymbol: wallet.coinSymbol,
      iconAsset: wallet.iconAsset,
      coinName: wallet.blockchainName,
      blockchainSubtitle: i18n.receiveBlockchainSubtitle(wallet.blockchainName),
      tabLabels: canToggle ? [i18n.receiveSubaddressTab, i18n.receivePrimaryTab] : null,
      selectedTab: _showSubaddress ? 0 : 1,
      onSelectTab: (i) => setState(() => _showSubaddress = i == 0),
      address: address ?? '',
      qrHeading: ready ? _heading(i18n, wallet, sub, showingSubaddress) : '',
      warning: warning,
      onCopy: () => _copyAddress(address!),
      assetOptions: assetOptions,
      onSelectAsset: _allAssets ? _selectAsset : null,
    );
  }

  String _heading(
    AppLocalizations i18n,
    CryptoWallet wallet,
    ({int index, String address})? sub,
    bool showingSubaddress,
  ) {
    if (showingSubaddress) {
      return sub != null ? '${i18n.receiveSubaddressTab} #${sub.index}' : i18n.receiveSubaddressTab;
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
