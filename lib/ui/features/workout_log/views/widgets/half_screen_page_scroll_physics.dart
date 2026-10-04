import 'package:flutter/material.dart';

/// A custom [PageScrollPhysics] that requires dragging at least half of the
/// screen width (50% threshold) before committing to a page transition.
///
/// Under standard Flutter [PageScrollPhysics], any release velocity (even a
/// slight micro-flick under 15-20px) forces the ballistic target calculation
/// to advance to the next page. This physics disregards micro-velocity additions
/// so that inadvertent slides, touches, or diagonal scroll drift under 50% will
/// safely spring back to the currently active page.
class HalfScreenPageScrollPhysics extends PageScrollPhysics {
  const HalfScreenPageScrollPhysics({super.parent});

  @override
  HalfScreenPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HalfScreenPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // If out of range and not headed back in range, defer to parent
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = toleranceFor(position);

    // Half-screen threshold: user must drag >= 50% of viewport width across.
    // If dragged < 50%, targetPage rounds back to current page; if >= 50%,
    // it rounds to the adjacent page.
    final double page = position.pixels / position.viewportDimension;
    final double targetPage = page.roundToDouble();
    final double target = targetPage * position.viewportDimension;

    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }
}
