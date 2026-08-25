import 'package:flutter/material.dart';

import 'package:spice_wallet/theme/brand.dart';

enum BrandButtonVariant { filled, outline }

/// Primary call-to-action — a 16px rounded rectangle (not a pill). Filled
/// cinnamon or outlined; full-width by default.
class BrandButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BrandButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;

  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BrandButtonVariant.filled,
    this.icon,
    this.expand = true,
    this.loading = false,
  });

  const BrandButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
  }) : variant = BrandButtonVariant.outline;

  @override
  Widget build(BuildContext context) {
    // `loading` keeps the enabled look but blocks taps and shows a spinner.
    final active = onPressed != null || loading;
    final interactive = onPressed != null && !loading;
    final filled = variant == BrandButtonVariant.filled;

    final Color bg;
    final Color fg;
    final BorderSide side;
    if (!active) {
      bg = filled ? BrandColors.surfaceMuted : Colors.transparent;
      fg = BrandColors.inkDisabled;
      side = filled ? BorderSide.none : const BorderSide(color: BrandColors.borderStrong);
    } else if (filled) {
      bg = BrandColors.cinnamon;
      fg = BrandColors.onCinnamon;
      side = BorderSide.none;
    } else {
      bg = Colors.transparent;
      fg = BrandColors.cinnamon;
      side = const BorderSide(color: BrandColors.cinnamon, width: 1);
    }

    final child = loading
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: BrandSpacing.sm),
              ],
              Text(label, style: BrandText.buttonLabel.copyWith(color: fg)),
            ],
          );

    final shape = RoundedRectangleBorder(borderRadius: BrandRadii.rButton, side: side);
    final button = Material(
      color: bg,
      shape: shape,
      child: InkWell(
        onTap: interactive ? onPressed : null,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: BrandSpacing.lg),
          child: child,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
