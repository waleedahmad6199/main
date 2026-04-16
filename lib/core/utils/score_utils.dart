// core/utils/score_utils.dart
//
// Efficiency Score Formula:
//   score = 100 − (delayImpact + blockedTaskIndex + reworkFactor)
//
// Assumptions:
//   delayImpact   = average(task.delayDays / task.estimatedDays) × 40
//                   Max contribution: 40 pts. Measures how delayed the project is
//                   on average relative to estimates.
//
//   blockedTaskIndex = (blockedTasks / totalTasks) × 35
//                   Max contribution: 35 pts. Penalizes having many blocked tasks
//                   since they indicate dependency bottlenecks.
//
//   reworkFactor  = min(avgReworkCount × 10, 25)
//                   Max contribution: 25 pts. Penalizes repeated rework cycles.
//                   Capped at 25 to avoid over-penalising a single bad task.
//
//   Total penalty is clamped to [0, 100] so the score stays in [0, 100].

import '../../models/task_model.dart';

class EfficiencyResult {
  final double score;
  final double delayImpact;
  final double blockedTaskIndex;
  final double reworkFactor;
  final int totalTasks;
  final int blockedTasks;

  const EfficiencyResult({
    required this.score,
    required this.delayImpact,
    required this.blockedTaskIndex,
    required this.reworkFactor,
    required this.totalTasks,
    required this.blockedTasks,
  });
}

EfficiencyResult calculateEfficiencyScore(List<TaskModel> tasks) {
  if (tasks.isEmpty) {
    return const EfficiencyResult(
      score: 100,
      delayImpact: 0,
      blockedTaskIndex: 0,
      reworkFactor: 0,
      totalTasks: 0,
      blockedTasks: 0,
    );
  }

  final total = tasks.length;

  // ── Delay Impact ──────────────────────────────────────────────────────────
  // For each non-completed task, compute delayDays / estimatedDays.
  // Completed tasks with no delay don't add penalty.
  final delayRatios = tasks.map((t) {
    if (t.estimatedDays == 0) return 0.0;
    return t.delayDays / t.estimatedDays;
  }).toList();

  final avgDelayRatio =
      delayRatios.reduce((a, b) => a + b) / delayRatios.length;
  final delayImpact = (avgDelayRatio * 40).clamp(0.0, 40.0);

  // ── Blocked Task Index ────────────────────────────────────────────────────
  final blockedCount = tasks.where((t) => t.isBlocked).length;
  final blockedTaskIndex = (blockedCount / total * 35).clamp(0.0, 35.0);

  // ── Rework Factor ─────────────────────────────────────────────────────────
  final totalRework = tasks.fold<int>(0, (sum, t) => sum + t.reworkCount);
  final avgRework = totalRework / total;
  final reworkFactor = (avgRework * 10).clamp(0.0, 25.0);

  // ── Final Score ───────────────────────────────────────────────────────────
  final penalty = delayImpact + blockedTaskIndex + reworkFactor;
  final score = (100 - penalty).clamp(0.0, 100.0);

  return EfficiencyResult(
    score: score,
    delayImpact: delayImpact,
    blockedTaskIndex: blockedTaskIndex,
    reworkFactor: reworkFactor,
    totalTasks: total,
    blockedTasks: blockedCount,
  );
}

/// Convenience: just the numeric score
double computeScore(List<TaskModel> tasks) =>
    calculateEfficiencyScore(tasks).score;