import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:spice_wallet/widgets/ui/ui.dart';

/// Numbered seed words in a 3-column grid, blurred behind a "Tap to reveal"
/// overlay until the user explicitly reveals them. Shared by the onboarding
/// generate-seed step and the settings reveal-seed screen.
class SeedGrid extends StatelessWidget {
  final List<String> words;
  final bool revealed;
  final String revealLabel;
  final String screenshotNote;
  final VoidCallback onReveal;

  const SeedGrid({
    super.key,
    required this.words,
    required this.revealed,
    required this.revealLabel,
    required this.screenshotNote,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final grid = GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      children: [for (var i = 0; i < words.length; i++) _WordCell(index: i + 1, word: words[i])],
    );

    if (revealed) return grid;

    // Covered: blurred cells behind a dark reveal affordance + a safety note.
    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: grid),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onReveal,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BrandColors.inverseSurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.visibility_off_outlined,
                      color: BrandColors.onCinnamon,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: BrandSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    decoration: BoxDecoration(
                      color: BrandColors.inverseSurface,
                      borderRadius: BrandRadii.rPill,
                    ),
                    child: Text(
                      revealLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: BrandColors.onCinnamon,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BrandSpacing.md),
            Text(
              screenshotNote,
              textAlign: TextAlign.center,
              style: BrandText.caption.copyWith(color: BrandColors.inkFaint),
            ),
          ],
        ),
      ],
    );
  }
}

/// One bordered seed-word cell: zero-padded index + the word in mono.
class _WordCell extends StatelessWidget {
  final int index;
  final String word;

  const _WordCell({required this.index, required this.word});

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      radius: 11,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Text(
            index.toString().padLeft(2, '0'),
            style: BrandText.mono.copyWith(fontSize: 11, color: BrandColors.inkFaint),
          ),
          const SizedBox(width: BrandSpacing.sm),
          Expanded(
            child: Text(
              word,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BrandColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The wallet birthday (restore-point month) with its rationale.
class SeedBirthdayCard extends StatelessWidget {
  final String label;
  final String reason;
  final String value;

  const SeedBirthdayCard({
    super.key,
    required this.label,
    required this.reason,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
      decoration: BoxDecoration(
        color: BrandColors.surfaceSunken,
        borderRadius: BrandRadii.rField,
        border: Border.all(color: BrandColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: BrandText.listTitle),
                const SizedBox(height: 2),
                Text(reason, style: BrandText.caption),
              ],
            ),
          ),
          const SizedBox(width: BrandSpacing.md),
          Text(value, style: BrandText.amount),
        ],
      ),
    );
  }
}
