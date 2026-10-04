import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controller interface to imperatively trigger the boundary shake and vibration.
class BoundaryShakeController {
  _BoundaryShakeWrapperState? _state;

  void _attach(_BoundaryShakeWrapperState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// Triggers device haptic vibration and screen shake animation.
  void triggerBoundaryFeedback() {
    HapticFeedback.heavyImpact();
    _state?.shake();
  }
}

/// A wrapper widget that provides horizontal spring-back shake animation
/// and haptic vibration when navigating beyond available record boundaries.
class BoundaryShakeWrapper extends StatefulWidget {
  final Widget child;
  final BoundaryShakeController? controller;

  const BoundaryShakeWrapper({
    required this.child,
    this.controller,
    super.key,
  });

  @override
  State<BoundaryShakeWrapper> createState() => _BoundaryShakeWrapperState();
}

class _BoundaryShakeWrapperState extends State<BoundaryShakeWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant BoundaryShakeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _animController.dispose();
    super.dispose();
  }

  void shake() {
    if (!mounted) return;
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final progress = _shakeAnimation.value;
        // Damped sine wave oscillation: 3 gentle oscillations dying out to 0
        final offset = 8.0 * math.sin(progress * math.pi * 5.0) * (1.0 - progress);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
