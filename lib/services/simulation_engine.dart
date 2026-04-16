// services/simulation_engine.dart
//
// Pure Dart simulation engine – no Firebase, no Flutter.
// Responsible for:
//   1. Propagating delay from a trigger task to all dependents (DFS)
//   2. Marking transitively-blocked tasks
//   3. Recalculating efficiency score
//   4. Returning a diff of changed tasks + impact log

import '../core/utils/graph_utils.dart';
import '../core/utils/score_utils.dart';
import '../models/simulation_log_model.dart';
import '../models/task_model.dart';

class SimulationResult {
  /// Updated versions of ALL tasks in the project (replace in-memory / Firestore)
  final List<TaskModel> updatedTasks;

  /// Only the tasks that actually changed (subset of updatedTasks)
  final List<TaskModel> changedTasks;

  /// Detailed per-task impact log
  final List<ImpactEntry> impactEntries;

  /// Score before the simulation
  final double scoreBefore;

  /// Score after applying delays
  final double scoreAfter;

  final List<String> affectedTaskIds;

  const SimulationResult({
    required this.updatedTasks,
    required this.changedTasks,
    required this.impactEntries,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.affectedTaskIds,
  });
}

class SimulationEngine {
  /// Run a delay simulation.
  ///
  /// [taskId]   – the task that directly receives the delay
  /// [delayDays] – number of days of delay to apply
  /// [allTasks] – all tasks in the project (must NOT be filtered by stage)
  ///
  /// Returns a [SimulationResult] with all mutations applied (immutably).
  static SimulationResult runSimulation({
    required String taskId,
    required int delayDays,
    required List<TaskModel> allTasks,
  }) {
    // ── 1. Score before ───────────────────────────────────────────────────
    final scoreBefore = computeScore(allTasks);

    // ── 2. Build dependency map (taskId → list of tasks that depend on it) ─
    final dependentMap = buildDependentMap(allTasks);

    // ── 3. Apply delay to trigger task ────────────────────────────────────
    final taskIndex = {for (final t in allTasks) t.id: t};

    final triggerTask = taskIndex[taskId];
    if (triggerTask == null) {
      throw ArgumentError('Task $taskId not found in allTasks');
    }

    // Mutate: set delay on trigger task (replace, don't accumulate)
    taskIndex[taskId] = triggerTask.copyWith(
      delayDays: delayDays,
      status: triggerTask.status == TaskStatus.completed
          ? TaskStatus.completed
          : TaskStatus.inProgress,
    );

    // ── 4. DFS propagation ────────────────────────────────────────────────
    // Propagation rule:
    //   Each dependent task inherits a fraction of the upstream delay:
    //   propagatedDelay = ceil(upstreamDelay × 1.0)
    //   (100% carry-over: full delay passes to dependents)
    //
    // A task becomes "blocked" if ANY of its direct dependencies has delay > 0.

    final impactEntries = <ImpactEntry>[];
    final affectedIds = <String>[];
    final changedIds = <String>{};

    void propagate(String nodeId, int incomingDelay) {
      final children = dependentMap[nodeId] ?? [];
      for (final childId in children) {
        if (childId == taskId) continue; // no self-loop
        final child = taskIndex[childId];
        if (child == null) continue;
        if (child.isCompleted) continue; // completed tasks absorb delay

        // Compute propagated delay for this hop (100% pass-through)
        final propagated = incomingDelay;
        if (propagated <= 0) continue;

        final newDelay = propagated;

        // Determine if this child has any unresolved dependencies with delays
        final hasBlockingDep = child.dependencyIds.any((depId) {
          final dep = taskIndex[depId];
          return dep != null && !dep.isCompleted && dep.delayDays > 0;
        });

        taskIndex[childId] = child.copyWith(
          delayDays: newDelay,
          status: hasBlockingDep ? TaskStatus.blocked : child.status,
        );

        impactEntries.add(ImpactEntry(
          taskId: childId,
          taskTitle: child.title,
          delayAdded: propagated,
          wasBlocked: hasBlockingDep,
        ));
        affectedIds.add(childId);
        changedIds.add(childId);

        // Recurse with the propagated delay as the new input
        propagate(childId, propagated);
      }
    }

    propagate(taskId, delayDays);
    changedIds.add(taskId);

    // ── 5. Build final task list ───────────────────────────────────────────
    final updatedTasks = taskIndex.values.toList();
    final changedTasks =
    updatedTasks.where((t) => changedIds.contains(t.id)).toList();

    // ── 6. Score after ────────────────────────────────────────────────────
    final scoreAfter = computeScore(updatedTasks);

    return SimulationResult(
      updatedTasks: updatedTasks,
      changedTasks: changedTasks,
      impactEntries: impactEntries,
      scoreBefore: scoreBefore,
      scoreAfter: scoreAfter,
      affectedTaskIds: affectedIds,
    );
  }
}