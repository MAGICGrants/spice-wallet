import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/screens/desktop/home_shell.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/util/secure_screen.dart';
import 'package:spice_wallet/widgets/seed_grid.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

/// Desktop: the seed phrase as a centered modal (opened from Settings); mobile
/// keeps the full-screen route.
Future<void> showRevealSeedSheet(BuildContext context) {
  return showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight(ctx)),
      child: const RevealSeedScreen(asModal: true),
    ),
  );
}

/// Shows the current wallet's seed phrase (the original mnemonic it was created
/// with) behind a tap-to-reveal cover. Reached from Settings after a biometric
/// gate. Screenshots are blocked while it's open.
class RevealSeedScreen extends StatefulWidget {
  /// Content-only render for a desktop modal (no shell, header or bottom button;
  /// the modal's X closes it).
  final bool asModal;

  const RevealSeedScreen({super.key, this.asModal = false});

  @override
  State<RevealSeedScreen> createState() => _RevealSeedScreenState();
}

class _RevealSeedScreenState extends State<RevealSeedScreen> with SecureScreenMixin {
  List<String> _words = [];
  DateTime? _restoreDate;
  bool _loaded = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stored = await Provider.of<WalletManager>(context, listen: false).loadStoredSeed();
    if (!mounted) return;
    setState(() {
      if (stored != null) {
        _words = stored.seed.mnemonic.split(' ');
        final from = stored.from;
        _restoreDate = from is RestoreFromDate ? from.date : null;
      }
      _loaded = true;
    });
  }

  /// The seed grid + birthday card — the body shared by the screen and modal.
  Widget _seedBody(AppLocalizations i18n) {
    if (!_loaded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Center(child: CircularProgressIndicator(color: BrandColors.primary)),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeedGrid(
          words: _words,
          revealed: _revealed,
          revealLabel: i18n.generateSeedReveal,
          // Screenshots aren't blocked on desktop, so drop the safety line there.
          screenshotNote: isDesktop ? null : i18n.generateSeedScreenshotNote,
          onReveal: () => setState(() => _revealed = true),
        ),
        if (_restoreDate != null) ...[
          const SizedBox(height: BrandSpacing.lg),
          // Blurred alongside the grid until revealed (the grid owns the pill).
          _blurUntilRevealed(
            SeedBirthdayCard(
              label: i18n.generateSeedBirthdayLabel,
              reason: i18n.generateSeedBirthdayReason,
              value: DateFormat.yMMM(
                Localizations.localeOf(context).toString(),
              ).format(_restoreDate!),
            ),
          ),
        ],
      ],
    );
  }

  Widget _blurUntilRevealed(Widget child) => _revealed
      ? child
      : ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: child);

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    // Desktop modal: title + subtitle + seed body; the modal card owns the
    // padding and its X closes it (no header back or bottom Hide button).
    if (widget.asModal) {
      final hpad = isDesktopModal ? 0.0 : 20.0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(hpad, 2, isDesktopModal ? 34 : 20, 6),
            child: Text(i18n.settingsSeedPhraseLabel, style: BrandText.title),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(hpad, 0, hpad, 16),
            child: Text(
              i18n.revealSeedSubtitleRevealed,
              style: BrandText.bodyMuted,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hpad),
              child: _seedBody(i18n),
            ),
          ),
        ],
      );
    }

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BrandSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: BrandSpacing.sm),
            BrandScreenHeader(
              onBack: () => Navigator.pop(context),
              center: Text(
                i18n.settingsSeedPhraseLabel,
                style: BrandText.appBar.copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(height: BrandSpacing.lg),
            Text(i18n.generateSeedTitleCovered, style: BrandText.title),
            const SizedBox(height: BrandSpacing.sm),
            Text(
              i18n.revealSeedSubtitleRevealed,
              style: BrandText.bodyMuted,
            ),
            const SizedBox(height: BrandSpacing.xl),
            Expanded(child: SingleChildScrollView(child: _seedBody(i18n))),
            BrandButton.secondary(
              label: _revealed ? i18n.revealSeedHideButton : i18n.revealSeedBackButton,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: BrandSpacing.sm),
          ],
        ),
      ),
    );
    if (isDesktop) {
      return DesktopShell(active: DesktopNav.settings, child: content);
    }
    return Scaffold(backgroundColor: BrandColors.paper, body: content);
  }
}
