import 'package:flutter/material.dart';

/// Spins [child] [turns] of a full rotation over [period], once, then stops
/// (default 0.5 = 180°). [alignment] is the pivot: default centre, but the spice
/// mark's viewBox isn't centred on the spiral origin, so pass the spiral centre
/// to spin in place instead of orbit.
class SpinningLogo extends StatefulWidget {
  final Widget child;
  final Duration period;
  final Alignment alignment;
  final Curve curve;
  final double turns;

  const SpinningLogo({
    super.key,
    required this.child,
    this.period = const Duration(seconds: 3),
    this.alignment = Alignment.center,
    this.curve = Curves.easeOut,
    this.turns = 0.5,
  });

  @override
  State<SpinningLogo> createState() => _SpinningLogoState();
}

class _SpinningLogoState extends State<SpinningLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..forward();
  late final CurvedAnimation _curved = CurvedAnimation(parent: _controller, curve: widget.curve);
  late final Animation<double> _turns = _curved.drive(Tween(begin: 0.0, end: widget.turns));

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _turns, alignment: widget.alignment, child: widget.child);
}
