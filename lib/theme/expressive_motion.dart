import 'package:flutter/material.dart';

/// Material 3 Expressive motion approximations for Flutter.
///
/// Maps M3 Expressive's spatial (overshooting spring) vs effects (damped, no
/// overshoot) tokens into Flutter [Curve] and [Duration] primitives.
class ExpressiveMotion {
  ExpressiveMotion._();

  /// Spatial spring approximation (moves, resizes, scale, progress rings).
  /// Mirrors `md.sys.motion.spring.default.spatial` with gentle overshoot.
  static const Curve spatialDefault = Cubic(0.38, 1.21, 0.22, 1.0);
  static const Duration spatialDefaultDuration = Duration(milliseconds: 420);

  /// Fast spatial spring for small interactive elements (chips, buttons).
  static const Curve spatialFast = Cubic(0.34, 1.32, 0.30, 1.0);
  static const Duration spatialFastDuration = Duration(milliseconds: 240);

  /// Effects curve (color, opacity, fades) — critically damped, zero overshoot.
  static const Curve effectsDefault = Curves.easeOutCubic;
  static const Duration effectsDefaultDuration = Duration(milliseconds: 220);
}

/// Subtle tactile spring press feedback for expressive interactive surfaces.
class ExpressiveTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const ExpressiveTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<ExpressiveTapScale> createState() => _ExpressiveTapScaleState();
}

class _ExpressiveTapScaleState extends State<ExpressiveTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: ExpressiveMotion.spatialFastDuration,
        curve: ExpressiveMotion.spatialFast,
        child: widget.child,
      ),
    );
  }
}
