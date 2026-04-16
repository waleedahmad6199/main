// core/widgets/shimmer_loading.dart
//
// Shimmer skeleton loading states for async content.
// Replaces bare CircularProgressIndicator with premium loading UX.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final int itemCount;
  final double height;
  final double spacing;

  const ShimmerLoading({
    super.key,
    this.itemCount = 3,
    this.height = 90,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade300;
    final highlightColor =
        isDark ? const Color(0xFF3D3D56) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            itemCount,
            (i) => Padding(
              padding: EdgeInsets.only(bottom: i < itemCount - 1 ? spacing : 0),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single shimmer box for inline loading
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade300;
    final highlightColor =
        isDark ? const Color(0xFF3D3D56) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
