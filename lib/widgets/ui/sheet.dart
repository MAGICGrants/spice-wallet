import 'package:flutter/material.dart';

import 'package:spice_wallet/theme/brand.dart';

/// Presents a brand-styled modal bottom sheet (paper ground, rounded top,
/// capped width). Use [SheetHandle]/[SheetIcon] inside for the grabber/title.
Future<T?> showBrandSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: BrandColors.paper,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

/// The little drag grabber at the top of a sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 5,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: BrandColors.borderStrong,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// Rounded icon tile used next to a sheet/dialog title.
class SheetIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;

  const SheetIcon({super.key, required this.icon, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
