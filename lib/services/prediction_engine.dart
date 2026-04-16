// services/prediction_engine.dart
//
// Pure Dart prediction engine for project completion forecasting.
// Computes estimated completion, risk scores, and optimization suggestions.

import '../models/task_model.dart';
import '../core/utils/graph_utils.dart';
import 'insight_engine.dart';

class PredictionResult {
  final int estimatedDaysRemaining;
  final int originalEstimate;
  final int totalDelayDays;
  final double riskScore; // 0-100, higher = more at risk
  final String status; // on_track, at_risk, critical
  final String summary;
  final List<String> optimizations;

  const PredictionResult({
    required this.estimatedDaysRemaining,
    required this.originalEstimate,
    required this.totalDelayDays,
    required this.riskScore,
    required this.status,
    required this.summary,
    required this.optimizations,
  });
}

class PredictionEngine {
  static PredictionResult predict(List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return const PredictionResult(
        estimatedDaysRemaining: 0,
        originalEstimate: 0,
        totalDelayDays: 0,
        riskScore: 0,
        status: 'on_track',
        summary: 'No tasks to analyze.',
        optimizations: [],
      );
    }

    // ── Compute critical path for timeline ──────────────────────────────
    final criticalPath = InsightEngine.computeCriticalPath(tasks);
    final criticalDays =
        criticalPath.fold<int>(0, (sum, t) => sum + t.totalDays);
    final completedOnCritical =
        criticalPath.where((t) => t.isCompleted).fold<int>(
              0,
              (sum, t) => sum + t.estimatedDays,
            );
    final remainingCriticalDays =
        (criticalDays - completedOnCritical).clamp(0, criticalDays);

    // ── Original estimate (no delays) ───────────────────────────────────
    final originalEstimate =
        criticalPath.fold<int>(0, (sum, t) => sum + t.estimatedDays);

    // ── Total delays ────────────────────────────────────────────────────
    final totalDelay = tasks.fold<int>(0, (sum, t) => sum + t.delayDays);

    // ── Risk score ──────────────────────────────────────────────────────
    final blockedCount = tasks.where((t) => t.isBlocked).length;
    final delayedCount = tasks.where((t) => t.delayDays > 0).length;
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final total = tasks.length;

    double riskScore = 0;
    // Blocked tasks contribute heavily
    riskScore += (blockedCount / total * 40).clamp(0, 40);
    // Delayed tasks
    riskScore += (delayedCount / total * 30).clamp(0, 30);
    // Lack of completion
    riskScore += ((1 - completedCount / total) * 20).clamp(0, 20);
    // High delay ratio on critical path
    final critPathDelayRatio = criticalPath.isEmpty
        ? 0.0
        : criticalPath
                .where((t) => t.delayDays > 0)
                .length /
            criticalPath.length;
    riskScore += (critPathDelayRatio * 10).clamp(0, 10);

    // ── Status ──────────────────────────────────────────────────────────
    String status;
    if (riskScore >= 60) {
      status = 'critical';
    } else if (riskScore >= 30) {
      status = 'at_risk';
    } else {
      status = 'on_track';
    }

    // ── Summary text ────────────────────────────────────────────────────
    String summary;
    if (status == 'critical') {
      summary =
          'Your project is at critical risk. $blockedCount blocked and $delayedCount delayed tasks '
          'need immediate attention. Estimated $remainingCriticalDays days remaining.';
    } else if (status == 'at_risk') {
      summary =
          'Your project is at risk of delays. $totalDelay total delay days accumulated. '
          'Estimated $remainingCriticalDays days to completion.';
    } else {
      summary = completedCount == total
          ? 'All tasks complete! Project finished successfully.'
          : 'Project is on track. $completedCount of $total tasks completed. '
              'Estimated $remainingCriticalDays days remaining.';
    }

    // ── Optimizations ───────────────────────────────────────────────────
    final optimizations = <String>[];

    // Find parallelizable tasks
    final parallel = InsightEngine.findParallelizableTasks(tasks);
    if (parallel.length >= 2) {
      optimizations.add(
        'Run "${parallel[0].title}" and "${parallel[1].title}" in parallel to save time.',
      );
    }

    // Find bottleneck
    final bottleneck = InsightEngine.detectBottleneck(tasks);
    if (bottleneck != null) {
      final depMap = buildDependentMap(tasks);
      final depCount = depMap[bottleneck.id]?.length ?? 0;
      if (depCount >= 2) {
        optimizations.add(
          'Prioritize "${bottleneck.title}" — it\'s blocking $depCount other tasks.',
        );
      }
    }

    // Suggest removing delays
    final mostDelayed = List<TaskModel>.from(tasks)
      ..sort((a, b) => b.delayDays.compareTo(a.delayDays));
    if (mostDelayed.isNotEmpty && mostDelayed.first.delayDays > 0) {
      optimizations.add(
        'Address delay on "${mostDelayed.first.title}" (+${mostDelayed.first.delayDays}d) to improve timeline.',
      );
    }

    return PredictionResult(
      estimatedDaysRemaining: remainingCriticalDays,
      originalEstimate: originalEstimate,
      totalDelayDays: totalDelay,
      riskScore: riskScore.clamp(0, 100),
      status: status,
      summary: summary,
      optimizations: optimizations,
    );
  }

  /// Build a context string from task data for the AI prediction API.
  static String buildProjectContext({
    required String projectTitle,
    required String projectDescription,
    required List<TaskModel> tasks,
    required double efficiencyScore,
  }) {
    final buf = StringBuffer();
    buf.writeln('PROJECT: $projectTitle');
    buf.writeln('DESCRIPTION: $projectDescription');
    buf.writeln('EFFICIENCY SCORE: ${efficiencyScore.toStringAsFixed(1)}/100');
    buf.writeln(
        'TASKS (${tasks.length} total, ${tasks.where((t) => t.isCompleted).length} completed):');

    for (final t in tasks) {
      buf.write('  - "${t.title}" | Status: ${t.status.name} | '
          'Est: ${t.estimatedDays}d');
      if (t.delayDays > 0) buf.write(' | Delay: +${t.delayDays}d');
      if (t.dependencyIds.isNotEmpty) {
        buf.write(' | Deps: ${t.dependencyIds.length}');
      }
      buf.writeln();
    }

    final blocked = tasks.where((t) => t.isBlocked).length;
    final delayed = tasks.where((t) => t.delayDays > 0).length;
    buf.writeln('\nSUMMARY: $blocked blocked, $delayed delayed');

    return buf.toString();
  }
}
