// core/widgets/animated_counter.dart
//
// Smooth animated number counter that tweens from old value to new value.
// Used for efficiency scores, task counts, and other numeric displays.

import 'package:flutter/material.dart';

class AnimatedCounter extends StatelessWidget {
  final double value;
  final Duration duration;
  final TextStyle? style;
  final String suffix;
  final int decimals;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 800),
    this.style,
    this.suffix = '',
    this.decimals = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animValue, _) {
        return Text(
          '${animValue.toStringAsFixed(decimals)}$suffix',
          style: style,
        );
      },
    );
  }
}
