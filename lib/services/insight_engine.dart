// services/insight_engine.dart
//
// Pure Dart logic for computing project insights from task data.
// No API calls needed — computes critical path, bottlenecks, parallelizable tasks, etc.

import 'package:flutter/material.dart';

import '../models/insight_model.dart';
import '../models/task_model.dart';
import '../core/utils/graph_utils.dart';

class InsightEngine {
  /// Compute all insights for a project from its tasks.
  static List<ProjectInsight> computeInsights(List<TaskModel> tasks) {
    if (tasks.isEmpty) return [];

    final insights = <ProjectInsight>[];

    // 1. Overall delay analysis
    _addDelayInsight(tasks, insights);

    // 2. Blocked task warnings
    _addBlockedInsight(tasks, insights);

    // 3. Critical path identification
    _addCriticalPathInsight(tasks, insights);

    // 4. Parallelizable task suggestions
    _addParallelInsight(tasks, insights);

    // 5. Bottleneck detection
    _addBottleneckInsight(tasks, insights);

    // 6. Completion progress
    _addProgressInsight(tasks, insights);

    // 7. Risk concentration
    _addRiskConcentrationInsight(tasks, insights);

    return insights;
  }

  static void _addDelayInsight(
      List<TaskModel> tasks, List<ProjectInsight> insights) {
    final totalDelay = tasks.fold<int>(0, (sum, t) => sum + t.delayDays);
    if (totalDelay > 0) {
      final delayedCount = tasks.where((t) => t.delayDays > 0).length;
      insights.add(ProjectInsight(
        title: 'Project delayed by $totalDelay days',
        description:
            '$delayedCount task(s) have accumulated delays. '
            'The longest delay is ${tasks.map((t) => t.delayDays).reduce((a, b) => a > b ? a : b)} days.',
        severity: totalDelay > 14
            ? InsightSeverity.critical
            : InsightSeverity.warning,
        icon: Icons.schedule_rounded,
        actionLabel: 'View delayed tasks',
      ));
    }
  }

  static void _addBlockedInsight(
      List<TaskModel> tasks, List<ProjectInsight> insights) {
    final blocked = tasks.where((t) => t.isBlocked).toList();
    if (blocked.isNotEmpty) {
      insights.add(ProjectInsight(
        title: '${blocked.length} task(s) are blocked',
        description:
            'Blocked tasks: ${blocked.map((t) => t.title).take(3).join(", ")}'
            '${blocked.length > 3 ? " and ${blocked.length - 3} more" : ""}. '
            'Resolve their dependencies to unblock progress.',
        severity: blocked.length >= 3
            ? InsightSeverity.critical
            : InsightSeverity.warning,
        icon: Icons.block_rounded,
        actionLabel: 'Resolve blockers',
      ));
    }
  }

  static void _addCriticalPathInsight(
      List<TaskModel> tasks, List<ProjectInsight> insights) {
    final path = computeCriticalPath(tasks);
    if (path.length >= 3) {
      final pathNames = path.map((t) => t.title).join(' → ');
      final totalDays = path.fold<int>(0, (sum, t) => sum + t.totalDays);
      insights.add(ProjectInsight(
        title: 'Critical path identified ($totalDays days)',
        description:
            'The longest dependency chain: $pathNames. '
            'Any delay on these tasks will directly delay the project.',
        severity: InsightSeverity.info,
        icon: Icons.timeline_rounded,
      ));
    }
  }

  static void _addParallelInsight(
      List<TaskModel> tasks, List<ProjectInsight> insights) {
    final parallel = findParallelizableTasks(tasks);
    if (parallel.isNotEmpty && parallel.length >= 2) {
      insights.add(ProjectInsight(
        title: '${parallel.length} tasks can run in parallel',
        description:
            'Tasks with no mutual dependencies: '
            '${parallel.map((t) => t.title).take(4).join(", ")}. '
            'Running them in parallel could save time.',
        severity: InsightSeverity.positive,
        icon: Icons.call_split_rounded,
        actionLabel: 'View parallel tasks',
      ));
    }
  }

  static void _addBottleneckInsight(
      List<TaskModel> tasks, List<ProjectInsight> insights) {
    final bottleneck = detectBottleneck(tasks);
    if (bottleneck != null) {
      final depMap = buildDependentMap(tasks);
      final dependentCount = depMap[bottleneck.id]?.length ?? 0;
      if (dependentCount >= 2) {
        insights.add(ProjectInsight(
          title: 'Bottleneck: "${bottleneck.title}"',
          description:
              'This task is blocking $dependentCount other tasks. '
              'Prioritize completing it to unblock downstream work.',
          severity: InsightSeverity.warning,
          icon: Icons.warning_amber_rounded,
          actionLabel: 'Focus on this task',
        ));
      }
    }
  }

  static void _addProgressInsight(
      List<TaskModel> tasks, List<ProjectInsight> insights) {
    final completed = tasks.where((t) => t.isCompleted).length;
    final pct = (completed / tasks.length * 100).round();

    if (pct >= 75) {
      insights.add(ProjectInsight(
        title: 'Great progress! $pct% complete',
        description:
            '$completed of ${tasks.length} tasks finished. '
            'You\'re in the home stretch.',
        severity: InsightSeverity.positive,
        icon: Icons.emoji_events_rounded,
      ));
    } else if (pct > 0) {
      insights.add(ProjectInsight(
        title: 'Project is $pct% complete',
        description:
            '$completed of ${tasks.length} tasks finished. '
            '${tasks.length - completed} remaining.',
        severity: InsightSeverity.info,
        icon: Icons.pie_chart_rounded,
      ));
    }
  }

  static void _addRiskConcentrationInsight(
      List<TaskModel> tasks, List<ProjectInsight> insights) {
    // Tasks with high delay ratio are high risk
    final risky = tasks.where((t) => t.delayRatio > 0.5 && !t.isCompleted).toList();
    if (risky.length >= 2) {
      insights.add(ProjectInsight(
        title: '${risky.length} tasks at high risk',
        description:
            'These tasks have delays exceeding 50% of their estimate: '
            '${risky.map((t) => t.title).take(3).join(", ")}.',
        severity: InsightSeverity.critical,
        icon: Icons.local_fire_department_rounded,
      ));
    }
  }

  // ── Graph analysis helpers ─────────────────────────────────────────────

  /// Find the critical path (longest dependency chain by total days).
  static List<TaskModel> computeCriticalPath(List<TaskModel> tasks) {
    if (tasks.isEmpty) return [];

    final taskMap = {for (final t in tasks) t.id: t};
    final depMap = buildDependentMap(tasks);

    // Find root tasks (no dependencies)
    final roots =
        tasks.where((t) => t.dependencyIds.isEmpty).toList();

    List<TaskModel> longestPath = [];

    void dfs(String nodeId, List<TaskModel> currentPath) {
      final node = taskMap[nodeId];
      if (node == null) return;
      final path = [...currentPath, node];

      final children = depMap[nodeId] ?? [];
      if (children.isEmpty) {
        // Leaf: compare path length
        final pathDays = path.fold<int>(0, (sum, t) => sum + t.totalDays);
        final longestDays =
            longestPath.fold<int>(0, (sum, t) => sum + t.totalDays);
        if (pathDays > longestDays) {
          longestPath = path;
        }
      } else {
        for (final child in children) {
          dfs(child, path);
        }
      }
    }

    for (final root in roots) {
      dfs(root.id, []);
    }

    // If no roots found (cycle case), return empty
    return longestPath;
  }

  /// Find tasks that can run in parallel (no mutual dependencies).
  static List<TaskModel> findParallelizableTasks(List<TaskModel> tasks) {
    final pending = tasks.where((t) => !t.isCompleted && !t.isBlocked).toList();
    // Tasks with no incomplete dependencies can run now
    final runnable = pending.where((task) {
      return task.dependencyIds.every((depId) {
        final dep = tasks.firstWhere((t) => t.id == depId,
            orElse: () => task);
        return dep.isCompleted;
      });
    }).toList();
    return runnable;
  }

  /// Find the task that blocks the most other tasks.
  static TaskModel? detectBottleneck(List<TaskModel> tasks) {
    if (tasks.isEmpty) return null;

    final depMap = buildDependentMap(tasks);
    TaskModel? bottleneck;
    int maxDependents = 0;

    for (final task in tasks) {
      if (task.isCompleted) continue;
      final count = depMap[task.id]?.length ?? 0;
      if (count > maxDependents) {
        maxDependents = count;
        bottleneck = task;
      }
    }

    return bottleneck;
  }
}
