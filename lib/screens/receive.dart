import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/util/secure_clipboard.dart';
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

  /// Whether the QR is grown to fill the screen. Brightness is held at full for
  /// exactly as long as this is true, and otherwise left to the system: the
  /// screen itself never takes it over.
  var _qrEnlarged = false;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    // Left with the QR still enlarged: hand brightness back on the way out.
    if (_qrEnlarged) _releaseBrightness();
    super.dispose();
  }

  void _toggleQr() {
    setState(() => _qrEnlarged = !_qrEnlarged);
    // No await before either call reaches the plugin, and both go down one
    // method channel, so the platform sees them in tap order: a quick
    // enlarge-shrink cannot land the raise after the release.
    _qrEnlarged ? _maximizeBrightness() : _releaseBrightness();
  }

  /// Turns the screen up while the QR is enlarged, so it still scans in
  /// daylight.
  Future<void> _maximizeBrightness() async {
    try {
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (error) {
      log(LogLevel.warn, 'Could not raise screen brightness for the QR code: $error');
    }
  }

  /// Hands brightness back to the system.
  ///
  /// This resets the override rather than setting it back to whatever the
  /// system brightness read before. An application override is an absolute
  /// value pinned on the window, and while one is set Android ignores the
  /// system brightness entirely: writing the old value back left the screen
  /// deaf to auto-brightness and to the user's own slider until the app was
  /// restarted (MAGICGrants/skylight-wallet#169). Resetting drops the
  /// override, so the window follows the system setting again -- which is both
  /// the brightness the user had before and the one they can keep changing.
  Future<void> _releaseBrightness() async {
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (error) {
      log(LogLevel.warn, 'Could not hand screen brightness back to the system: $error');
    }
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

    return ReceiveView(
      labels: ReceiveLabels(
        title: i18n.receiveTitle,
        copyAddress: i18n.receiveCopyAddress,
        enlargeQr: i18n.receiveEnlargeQr,
        shrinkQr: i18n.receiveShrinkQr,
      ),
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
      // Mobile only: the hint promises a brighter screen, and brightness is
      // only managed on phones.
      qrEnlarged: _qrEnlarged,
      onToggleQr: _isMobile ? _toggleQr : null,
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
