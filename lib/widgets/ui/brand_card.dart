import 'package:flutter/material.dart';

import 'package:spice_wallet/theme/brand.dart';

/// Rounded warm surface. The base container for most content blocks.
class BrandCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool border;
  final List<BoxShadow> shadow;
  final BorderRadius radius;
  final VoidCallback? onTap;

  const BrandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BrandSpacing.lg),
    this.color,
    this.border = false,
    this.shadow = BrandShadows.soft,
    this.radius = BrandRadii.rCard,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? BrandColors.paper,
      borderRadius: radius,
      boxShadow: shadow,
      border: border ? Border.all(color: BrandColors.border) : null,
    );
    final content = Padding(padding: padding, child: child);
    if (onTap == null) return DecoratedBox(decoration: decoration, child: content);
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}
