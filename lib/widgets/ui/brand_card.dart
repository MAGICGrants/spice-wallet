import 'package:flutter/material.dart';

import 'package:spice_wallet/theme/brand.dart';

/// A plain brand card: solid [color] fill, hairline [borderColor] outline, and
/// rounded corners. Wraps the `Container(decoration: BoxDecoration(...))` that
/// otherwise repeats across every screen.
class BrandCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double radius;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final Clip clipBehavior;
  final List<BoxShadow>? shadow;

  const BrandCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.radius = 16,
    this.color = BrandColors.card,
    this.borderColor = BrandColors.border,
    this.borderWidth = 1,
    this.clipBehavior = Clip.none,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}
