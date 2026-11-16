import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/l10n/shared_strings.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/screens/desktop/home_shell.dart';
import 'package:spice_wallet/screens/desktop/receive_view.dart';
import 'package:spice_wallet/screens/receive_address.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/util/labeled_addresses.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/util/qr_brightness.dart';
import 'package:spice_wallet/util/secure_clipboard.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';
import 'package:wallet_monero/wallet_monero.dart' show MoneroWallet;

class ReceiveScreenArgs {
  final String coinSymbol;

  /// When true (entered from the multicoin home), the coin card becomes an asset
  /// dropdown so the user can pick which chain to receive on.
  final bool allAssets;

  /// The desktop back link's label: where Back returns to. Null: the coin's
  /// own page (its blockchain name), which is where Send and Receive open from
  /// unless the caller says otherwise.
  final String? backLabel;

  ReceiveScreenArgs({required this.coinSymbol, this.allAssets = false, this.backLabel});
}

/// Opens the system share sheet on [address], anchored at [origin]: Receive's
/// share button, and a used address's.
///
/// [origin] is the share button's rect. iOS presents the sheet as a popover
/// pointing at it and share_plus rejects the call without one, so dropping it
/// left the button doing nothing at all. Awaited and caught for the same
/// reason: a fire-and-forget share turns every failure into silence.
Future<void> shareAddress(BuildContext context, String address, Rect? origin) async {
  final i18n = AppLocalizations.of(context)!;
  final toast = BrandToast.of(context);
  try {
    await SharePlus.instance.share(ShareParams(text: address, sharePositionOrigin: origin));
  } catch (error) {
    log(LogLevel.error, 'Address share failed (origin=${origin ?? 'none'}): $error');
    toast.show(i18n.shared.receiveShareError);
  }
}

/// Receive's tabs. A Monero wallet with subaddresses has Subaddress, Primary
/// and Labeled; a Bitcoin one, whose every address is just an address, has
/// Address and Labeled; a chain with one address (Ethereum) has none.
enum _ReceiveTab { subaddress, primary, address, labeled }

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> with QrBrightness {
  /// Index into the chain's tabs: the first, its fresh address, until the user
  /// picks another.
  var _tab = 0;

  String _coinSymbol = 'XMR';
  bool _allAssets = false;
  String? _backLabel;
  bool _argsLoaded = false;

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments as ReceiveScreenArgs?;
    if (args != null) {
      _coinSymbol = args.coinSymbol;
      _allAssets = args.allAssets;
      _backLabel = args.backLabel;
    }
  }

  void _selectAsset(String coinSymbol) {
    if (coinSymbol == _coinSymbol) return;
    setState(() {
      _coinSymbol = coinSymbol;
      _tab = 0; // back to the new chain's fresh address
    });
  }

  void _selectTab(List<_ReceiveTab> tabs, int index) {
    // The Labeled tab has no QR to keep bright.
    if (tabs[index] == _ReceiveTab.labeled && qrEnlarged) toggleQr();
    setState(() => _tab = index);
  }

  void _copyAddress(String address) {
    final i18n = AppLocalizations.of(context)!;
    SecureClipboard.copy(address);
    showCopyToast(context, i18n.shared.addressCopied);
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
    // The address and the index that labels it, as one value: read separately
    // they can name different subaddresses.
    final sub = isDemoMode ? null : monero?.unusedSubaddress;
    // The toggle needs a subaddress to toggle to. Until there is one (the
    // server has not answered yet, or cannot be reached at all) the primary
    // address is shown: every server scans it. Waiting for the subaddress
    // instead spun forever with no connection, where Bitcoin and Ethereum
    // show their address straight away.
    final canToggle = monero != null && subSupported == true && sub != null;

    final tabs = [
      if (canToggle) ...[
        _ReceiveTab.subaddress,
        _ReceiveTab.primary,
        _ReceiveTab.labeled,
      ] else if (wallet.rotatingAddressKind == RotatingAddressKind.address) ...[
        _ReceiveTab.address,
        _ReceiveTab.labeled,
      ],
    ];
    // Clamped: Monero's tabs come and go with the server's answer.
    final tab = tabs.isEmpty ? null : tabs[_tab.clamp(0, tabs.length - 1)];
    final tabLabels = tabs.isEmpty
        ? null
        : [
            for (final t in tabs)
              switch (t) {
                _ReceiveTab.subaddress => i18n.shared.receiveSubaddressTab,
                _ReceiveTab.primary => i18n.shared.receivePrimaryTab,
                _ReceiveTab.address => i18n.shared.receiveAddressTab,
                _ReceiveTab.labeled => i18n.shared.receiveLabeledTab,
              },
          ];
    final labeledCoin = tab == _ReceiveTab.labeled ? labeledAddressCoinOf(wallet) : null;
    final tabBody = labeledCoin == null ? null : _labeledList(i18n, wallet, labeledCoin);

    String? address;
    if (monero == null) {
      address = receiveAddress ?? primaryAddress;
    } else if (canToggle && tab == _ReceiveTab.subaddress) {
      address = sub.address;
    } else if (primaryAddress.isNotEmpty) {
      address = primaryAddress;
    }

    final showingSubaddress = tab == _ReceiveTab.subaddress;
    // The Labeled tab lists addresses rather than showing one.
    final ready = tabBody != null || address != null;
    final warning = _warning(
      i18n,
      monero,
      isDemoMode,
      subSupported,
      sub,
      unusedIndexSupported,
      showingPrimary: tab == _ReceiveTab.primary,
    );

    if (isDesktop) {
      return DesktopShell(
        active: DesktopNav.home,
        child: DesktopReceiveView(
          title: i18n.shared.receiveTitle,
          copyLabel: i18n.shared.receiveCopyAddress,
          qrHint: i18n.receiveQrHint(wallet.blockchainName),
          coinSymbol: wallet.coinSymbol,
          iconAsset: wallet.iconAsset,
          coinName: wallet.blockchainName,
          backLabel: _backLabel ?? wallet.blockchainName,
          blockchainSubtitle: i18n.receiveBlockchainSubtitle(wallet.blockchainName),
          ready: ready,
          address: address ?? '',
          qrHeading: address != null ? _heading(i18n, wallet, sub, showingSubaddress) : '',
          tabLabels: tabLabels,
          selectedTab: tab == null ? 0 : tabs.indexOf(tab),
          onSelectTab: (i) => _selectTab(tabs, i),
          tabBody: tabBody,
          warning: warning,
          onCopy: () => _copyAddress(address!),
          onBack: () => Navigator.pop(context),
          assetOptions: assetOptions,
          onSelectAsset: _allAssets ? _selectAsset : null,
        ),
      );
    }

    return ReceiveView(
      labels: ReceiveLabels(
        title: i18n.shared.receiveTitle,
        copyAddress: i18n.shared.receiveCopyAddress,
        enlargeQr: i18n.shared.receiveEnlargeQr,
        shrinkQr: i18n.shared.receiveShrinkQr,
      ),
      onBack: () => Navigator.pop(context),
      onShare: _isMobile ? (origin) => shareAddress(context, address!, origin) : null,
      ready: ready,
      coinSymbol: wallet.coinSymbol,
      iconAsset: wallet.iconAsset,
      coinName: wallet.blockchainName,
      blockchainSubtitle: i18n.receiveBlockchainSubtitle(wallet.blockchainName),
      tabLabels: tabLabels,
      selectedTab: tab == null ? 0 : tabs.indexOf(tab),
      onSelectTab: (i) => _selectTab(tabs, i),
      tabBody: tabBody,
      address: address ?? '',
      qrHeading: address != null ? _heading(i18n, wallet, sub, showingSubaddress) : '',
      warning: warning,
      onCopy: () => _copyAddress(address!),
      assetOptions: assetOptions,
      onSelectAsset: _allAssets ? _selectAsset : null,
      // Mobile only: the hint promises a brighter screen, and brightness is
      // only managed on phones.
      qrEnlarged: qrEnlarged,
      onToggleQr: _isMobile ? toggleQr : null,
    );
  }

  /// The Labeled tab: every used address of [wallet], under its label if it has
  /// one. A row opens the address's own screen; Label opens the label sheet.
  Widget _labeledList(AppLocalizations i18n, CryptoWallet wallet, LabeledAddressCoin coin) {
    final labels = context.watch<AddressLabelModel>();
    return FutureBuilder(
      // Keyed on the chain, so switching chains starts from a spinner rather
      // than the last chain's list.
      key: ValueKey(coin.coinSymbol),
      future: usedReceiveAddresses(wallet),
      builder: (context, snapshot) {
        final used = snapshot.data;
        return LabeledAddressList(
          strings: i18n.shared,
          coin: coin,
          entries: used == null
              ? null
              : [
                  for (final u in used)
                    (used: u, label: labels.labelFor(coin.coinSymbol, u.address)),
                ],
          onOpen: (entry) => Navigator.pushNamed(
            context,
            '/receive_address',
            arguments: ReceiveAddressArgs(
              coinSymbol: coin.coinSymbol,
              used: entry.used,
              backLabel: i18n.shared.receiveTitle,
            ),
          ),
          onLabel: (entry) => editAddressLabel(context, coin, entry.used),
        );
      },
    );
  }

  String _heading(
    AppLocalizations i18n,
    CryptoWallet wallet,
    ({int index, String address})? sub,
    bool showingSubaddress,
  ) {
    if (showingSubaddress) {
      return sub != null
          ? '${i18n.shared.receiveSubaddressTab} #${sub.index}'
          : i18n.shared.receiveSubaddressTab;
    }
    return i18n.shared.receiveAddressHeading(wallet.blockchainName);
  }

  String? _warning(
    AppLocalizations i18n,
    MoneroWallet? monero,
    bool isDemoMode,
    bool? subSupported,
    ({int index, String address})? sub,
    bool? unusedIndexSupported, {
    required bool showingPrimary,
  }) {
    if (monero == null || isDemoMode) return null;
    if (subSupported == false) return i18n.shared.receiveServerNoSubaddressesWarn;
    if (sub == null) return i18n.shared.receiveSubaddressUnavailableWarn;
    if (showingPrimary) return i18n.shared.receivePrimaryAddressWarn;
    if (unusedIndexSupported == false) return i18n.shared.receiveMaxSubaddressesReachedWarn;
    return null;
  }
}
