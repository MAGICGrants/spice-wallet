import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/screens/settings.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// The top-level desktop destinations. [coin] is a specific blockchain screen
/// under the expandable Home group (its symbol in [DesktopShell.activeCoinSymbol]).
enum DesktopNav { home, coin, history, addressBook, settings }

/// The chrome for wallet_ui's shared sub-pages (the legal pages): the back
/// links' strings, and Settings' place in the sidebar when opened from there.
SubPageChrome subPageChrome(BuildContext context) {
  final i18n = AppLocalizations.of(context)!;
  return SubPageChrome(
    back: i18n.back,
    parent: i18n.navigationBarSettings,
    desktopShell: (page) => DesktopShell(active: DesktopNav.settings, child: page),
  );
}

/// Two-pane desktop chrome: a fixed left sidebar (brand, nav, Tor status,
/// version) with the screen's content on the right. Shared by the desktop
/// screens so the sidebar stays put.
///
/// The sidebar is a [Hero] (like the mobile nav bar) so it flies in place across
/// route transitions instead of sliding with the page — the content animates,
/// the sidebar looks fixed. Modals stay on the root navigator, so they still
/// cover (and dim) the whole window, sidebar included.
class DesktopShell extends StatefulWidget {
  final DesktopNav active;

  /// When [active] is [DesktopNav.coin], the symbol of the chain being shown, so
  /// the matching sidebar sub-item highlights.
  final String? activeCoinSymbol;
  final Widget child;

  const DesktopShell({super.key, required this.active, this.activeCoinSymbol, required this.child});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  // Expansion of the Home group's chain list. Static so it survives the fresh
  // shell mounted on each navigation (like the cached version string).
  static bool _homeExpanded = true;

  // Cached across shells: each nav click mounts a fresh shell, and a per-instance
  // reload would blank the version line for a frame (a flicker) every time.
  static String _cachedVersion = '';
  String _version = _cachedVersion;

  @override
  void initState() {
    super.initState();
    if (_cachedVersion.isEmpty) {
      PackageInfo.fromPlatform().then((info) {
        _cachedVersion = 'v${info.version} · build ${info.buildNumber}';
        if (mounted) setState(() => _version = _cachedVersion);
      });
    }
  }

  void _go(String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushNamed(context, route);
  }

  void _goCoin(String symbol) {
    if (widget.active == DesktopNav.coin && widget.activeCoinSymbol == symbol) return;
    Navigator.pushNamed(context, '/coin_home', arguments: CoinHomeScreenArgs(coinSymbol: symbol));
  }

  /// Readable cap for a screen's content so it doesn't span an ultra-wide window
  /// (the child adds its own gutters, so this includes ~44px each side).
  static const contentMaxWidth = 948.0;

  /// Configured non-token chains, each with its total asset value (own coin +
  /// tokens, formatted), ordered by that value descending. Computed here (not
  /// inside the Hero child) so the sidebar the Hero flies is plain data. [fiat]
  /// is null when prices are disabled or nothing can be priced yet.
  List<({CryptoWallet wallet, String? fiat})> _chainNavItems(BuildContext context) {
    final manager = context.watch<WalletManager>();
    final fiatRate = context.watch<FiatRateModel>();
    bool isChain(CryptoWallet w) => !isTokenWallet(w) && w.connectionAddress.isNotEmpty;

    final entries =
        [
          for (final w in manager.allWallets.where(isChain))
            (wallet: w, value: aggregateUnlockedFiat(manager, w, fiatRate.rateFor)),
        ]..sort(
          (a, b) =>
              (b.value ?? double.negativeInfinity).compareTo(a.value ?? double.negativeInfinity),
        );

    return [
      for (final e in entries)
        (
          wallet: e.wallet,
          fiat: (fiatRate.isDisabled || e.value == null)
              ? null
              : formatFiat(e.value!, fiatRate.fiatCurrency),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final chains = _chainNavItems(context);
    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flies in place across transitions, so the sidebar doesn't slide with
          // the page. Kept out of the page's own transition, like the mobile nav.
          // placeholderBuilder keeps it painted in place during the flight, so
          // instant (zero-duration) tab switches don't blink an empty gap.
          Hero(
            tag: 'desktop-sidebar',
            // The sidebar flies in place so it doesn't slide with the page. The
            // default flight shows the destination copy opaquely (no cross-fade,
            // so identical sidebars don't dim mid-flight); placeholderBuilder
            // keeps the source painted so instant switches don't blink a gap. The
            // flown child is plain data (chains passed in), so nothing re-runs a
            // provider lookup mid-flight — that was the earlier flicker.
            placeholderBuilder: (context, heroSize, child) => child,
            child: _sidebar(context, chains),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar(BuildContext context, List<({CryptoWallet wallet, String? fiat})> chains) {
    final i18n = AppLocalizations.of(context)!;
    // The Hero lifts this into the overlay mid-flight, outside any Scaffold, so
    // give it a Material for text styling (transparent to keep the fill).
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: BrandColors.surfaceSunken,
          border: Border(right: BorderSide(color: BrandColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                children: [
                  SvgPicture.asset('assets/spice-icon.svg', width: 28, height: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Spice Wallet',
                    style: TextStyle(
                      fontFamily: 'Ubuntu',
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.primaryDeep,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _homeGroup(i18n, chains),
            // No Swap entry until swaps exist; the home's Swap button says so.
            const SizedBox(height: 2),
            _navItem(DesktopNav.history, Icons.history, i18n.navigationBarHistory, '/history'),
            const SizedBox(height: 2),
            _navItem(
              DesktopNav.addressBook,
              Icons.people_outline,
              i18n.addressBookTitle,
              '/address_book',
            ),
            const Spacer(),
            // Settings opens as a modal over the current screen (not a page).
            _navTile(
              icon: Icons.tune,
              label: i18n.navigationBarSettings,
              active: false,
              onTap: () => showSettingsSheet(context),
            ),
            const SizedBox(height: 6),
            TorStatusPill(
              labels: TorStatusLabels(
                connected: i18n.homeTorConnected,
                connecting: i18n.homeTorConnecting,
                disconnected: i18n.homeTorDisconnected,
                off: i18n.homeTorOff,
                externalConnected: i18n.homeTorExternalConnected,
                externalConnecting: i18n.homeTorExternalConnecting,
                externalDisconnected: i18n.homeTorExternalDisconnected,
              ),
            ),
            if (_version.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 1),
                child: Text(
                  'Spice Wallet $_version',
                  style: TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 10.5,
                    height: 1.5,
                    color: BrandColors.inkFaint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(DesktopNav nav, IconData icon, String label, String route) {
    // Always clickable (cursor + ripple), even when this tab is the active one;
    // _go no-ops when you're already on that exact route.
    return _navTile(
      icon: icon,
      label: label,
      active: widget.active == nav,
      onTap: () => _go(route),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onTap,
  }) {
    // Inactive label/icon use inkMuted; the design's #5D4231 has no palette token.
    final fg = active ? BrandColors.primaryDeep : BrandColors.inkMuted;
    return Material(
      color: active ? BrandColors.paper : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? BrandColors.border : Colors.transparent),
      ),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Ubuntu',
                  fontSize: 14,
                  height: 1,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The expandable Home group: the aggregate overview + a chevron that toggles
  /// the per-chain sub-items (each opens that blockchain's screen).
  Widget _homeGroup(AppLocalizations i18n, List<({CryptoWallet wallet, String? fiat})> chains) {
    // Home highlights only when it's the active screen; a selected coin does not
    // tint Home (per the design — the pill on the coin marks the selection).
    final homeSelected = widget.active == DesktopNav.home;
    final fg = homeSelected ? BrandColors.primaryDeep : BrandColors.inkMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: homeSelected ? BrandColors.paper : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: homeSelected ? BrandColors.border : Colors.transparent),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _go('/wallet_home'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 11, 4, 11),
                    child: Row(
                      children: [
                        Icon(Icons.home_outlined, size: 19, color: fg),
                        const SizedBox(width: 12),
                        Text(
                          i18n.navigationBarHome,
                          style: TextStyle(
                            fontFamily: 'Ubuntu',
                            fontSize: 14,
                            height: 1,
                            fontWeight: homeSelected ? FontWeight.w500 : FontWeight.w400,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // No chevron when there are no chains to expand.
              if (chains.isNotEmpty)
                InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => setState(() => _homeExpanded = !_homeExpanded),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      _homeExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: BrandColors.inkFaint,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_homeExpanded)
          Padding(
            // Indent the chain list under Home (design: padding-left 22).
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < chains.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  _coinTile(chains[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _coinTile(({CryptoWallet wallet, String? fiat}) item) {
    final wallet = item.wallet;
    final active = widget.active == DesktopNav.coin && widget.activeCoinSymbol == wallet.coinSymbol;
    return Material(
      color: active ? BrandColors.paper : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? BrandColors.border : Colors.transparent),
      ),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: BorderRadius.circular(12),
        onTap: () => _goCoin(wallet.coinSymbol),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 28),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      wallet.blockchainName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Ubuntu',
                        fontSize: 13.5,
                        height: 1,
                        // Selected weight matches the other nav items (w500).
                        fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                        color: BrandColors.ink,
                      ),
                    ),
                    if (item.fiat != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.fiat!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Ubuntu Mono',
                          fontSize: 11,
                          height: 1,
                          color: BrandColors.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
