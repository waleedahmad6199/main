// models/insight_model.dart
//
// Model for computed project insights.

import 'package:flutter/material.dart';

enum InsightSeverity { info, warning, critical, positive }

class ProjectInsight {
  final String title;
  final String description;
  final InsightSeverity severity;
  final IconData icon;
  final String? actionLabel;

  const ProjectInsight({
    required this.title,
    required this.description,
    required this.severity,
    required this.icon,
    this.actionLabel,
  });

  Color get color {
    switch (severity) {
      case InsightSeverity.critical:
        return const Color(0xFFEF5350);
      case InsightSeverity.warning:
        return const Color(0xFFFFC107);
      case InsightSeverity.positive:
        return const Color(0xFF4CAF50);
      case InsightSeverity.info:
        return const Color(0xFF00BCD4);
    }
  }

  String get emoji {
    switch (severity) {
      case InsightSeverity.critical:
        return '🔥';
      case InsightSeverity.warning:
        return '⚠️';
      case InsightSeverity.positive:
        return '✅';
      case InsightSeverity.info:
        return '💡';
    }
  }
}
