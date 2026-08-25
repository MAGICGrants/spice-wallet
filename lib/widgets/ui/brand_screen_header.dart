import 'package:flutter/material.dart';

import 'package:spice_wallet/widgets/ui/icon_circle_button.dart';

/// Standard onboarding/screen header: a back button on the left, a centered
/// element (step dots or a title), and an optional right-hand action — with
/// spacers so the centre stays centred.
class BrandScreenHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final Widget? center;
  final Widget? action;

  const BrandScreenHeader({super.key, this.onBack, this.center, this.action});

  @override
  Widget build(BuildContext context) {
    // Stack (not Row) so the centre stays at the true middle of the width,
    // regardless of the side elements' sizes.
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          if (center != null) Center(child: center),
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconCircleButton(icon: Icons.arrow_back, onPressed: onBack),
            ),
          if (action != null) Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}
