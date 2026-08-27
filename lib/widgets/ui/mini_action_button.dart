import 'package:flutter/material.dart';

import 'package:spice_wallet/theme/brand.dart';

/// Small tan icon+label pill (Paste / Scan / Contacts). [bordered] adds a
/// hairline + slightly rounder corners (contact sheet); the plain variant is
/// used on the send screen's To card. Wrap in [Expanded] to fill a row.
class MiniActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool bordered;

  const MiniActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: BrandColors.surfaceSunken,
          border: bordered ? Border.all(color: BrandColors.border) : null,
          borderRadius: BorderRadius.circular(bordered ? 12 : 10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: BrandColors.cinnamonDeep),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: BrandColors.cinnamonDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
