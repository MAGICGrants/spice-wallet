import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_infra/wallet_infra.dart';

/// The top-level desktop destinations, mirroring the mobile navigation bar.
enum DesktopNav { home, history, addressBook, settings }

/// Two-pane desktop chrome: a fixed left sidebar (brand, nav, Tor status,
/// version) with the screen's content on the right. Shared by the desktop
/// home/history/address-book/settings screens so the sidebar stays put.
class DesktopShell extends StatefulWidget {
  final DesktopNav active;
  final Widget child;
  const DesktopShell({super.key, required this.active, required this.child});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} · build ${info.buildNumber}');
    });
  }

  void _go(String route) {
    Navigator.pushNamed(context, route);
  }

  /// Readable cap for a screen's content so it doesn't span an ultra-wide window
  /// (the child adds its own gutters, so this includes ~44px each side).
  static const contentMaxWidth = 948.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sidebar(context),
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

  Widget _sidebar(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    return Container(
      width: 236,
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
          _navItem(DesktopNav.home, Icons.home_outlined, i18n.navigationBarHome, '/wallet_home'),
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
          _navItem(DesktopNav.settings, Icons.tune, i18n.navigationBarSettings, '/settings'),
          const SizedBox(height: 6),
          _torStatus(),
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
    );
  }

  Widget _navItem(DesktopNav nav, IconData icon, String label, String route) {
    final active = widget.active == nav;
    return _navTile(
      icon: icon,
      label: label,
      active: active,
      onTap: active ? null : () => _go(route),
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

  Widget _torStatus() {
    // Read once at build; Tor connects at launch and stays. Not a live stream.
    final status = TorService.sharedInstance.status;
    final (Color color, String text) = switch (status) {
      TorConnectionStatus.connected => (BrandColors.purple, 'Tor · connected'),
      TorConnectionStatus.connecting => (BrandColors.warning, 'Tor · connecting'),
      TorConnectionStatus.disconnected => (BrandColors.inkFaint, 'Tor · off'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 12,
              height: 1,
              color: BrandColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
