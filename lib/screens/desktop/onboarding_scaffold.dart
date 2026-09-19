import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:spice_wallet/widgets/ui/ui.dart';

/// A footnote row in the dark left pane: small accent icon + muted line.
class OnboardingNote {
  final IconData icon;
  final String text;
  const OnboardingNote(this.icon, this.text);
}

/// Shared two-pane desktop onboarding layout: a dark explainer pane (logo,
/// title, description, footnotes) on the left, and a stepped content pane
/// (Step N of M + progress dots, [content], Back/Continue) on the right.
/// Colours are spicePalette tokens; the dark pane uses light-on-`ink` text and
/// the dark-variant `primary` accent, matching the design.
class DesktopOnboardingScaffold extends StatelessWidget {
  final String title;
  final String description;
  final List<OnboardingNote> notes;
  final int step; // 1-based
  final int totalSteps;
  final Widget content;
  final VoidCallback? onBack;
  final VoidCallback? onContinue;
  final String backLabel;
  final String continueLabel;
  final bool continueEnabled;
  final bool loading;

  const DesktopOnboardingScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.step,
    required this.totalSteps,
    required this.content,
    required this.continueLabel,
    this.notes = const [],
    this.onBack,
    this.onContinue,
    this.backLabel = 'Back',
    this.continueEnabled = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _leftPane(),
          Expanded(child: _rightPane()),
        ],
      ),
    );
  }

  Widget _leftPane() {
    return Container(
      width: 436,
      color: BrandColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset('assets/spice-mark.svg', height: 52),
          const SizedBox(height: 30),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 30,
              height: 1.18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.36,
              color: BrandColors.surfaceTinted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Ubuntu',
              fontSize: 14,
              height: 1.7,
              color: BrandColors.inkDisabled,
            ),
          ),
          const Spacer(),
          for (final note in notes) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(note.icon, size: 17, color: BrandColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      note.text,
                      style: TextStyle(
                        fontFamily: 'Ubuntu',
                        fontSize: 13,
                        height: 1.6,
                        color: BrandColors.frameEdge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rightPane() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepRow(),
          const SizedBox(height: 30),
          Expanded(child: content),
          const SizedBox(height: 20),
          Row(
            children: [
              if (onBack != null)
                BrandButton(
                  label: backLabel,
                  onPressed: onBack,
                  variant: BrandButtonVariant.ghost,
                  expand: false,
                ),
              const Spacer(),
              SizedBox(
                width: 200,
                child: BrandButton(
                  label: continueLabel,
                  loading: loading,
                  onPressed: continueEnabled ? onContinue : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepRow() {
    return Row(
      children: [
        Text(
          'Step $step of $totalSteps',
          style: TextStyle(
            fontFamily: 'Ubuntu Mono',
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: BrandColors.inkFaint,
          ),
        ),
        const SizedBox(width: 14),
        for (var i = 0; i < totalSteps; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == step - 1 ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == step - 1 ? BrandColors.primary : BrandColors.borderStrong,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}

/// A selectable option card used by the onboarding choice screens (Tor, price
/// display, wallet setup): radio + accent icon + title + description.
class OnboardingRadioCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Widget? trailing;

  const OnboardingRadioCard({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? BrandColors.primary : BrandColors.inkFaint;
    return Tappable(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? BrandColors.surfaceSunken : BrandColors.card,
          border: Border.all(
            color: selected ? BrandColors.primary : BrandColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _Radio(selected: selected),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: accent),
                      const SizedBox(width: 9),
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Ubuntu',
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: BrandColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Ubuntu',
                      fontSize: 13,
                      height: 1.6,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(height: 14), trailing!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;
  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BrandColors.card,
        border: Border.all(
          color: selected ? BrandColors.primary : BrandColors.frameEdge,
          width: selected ? 5.5 : 1.5,
        ),
      ),
    );
  }
}
