// providers/whatif_provider.dart
//
// Local state management for interactive what-if simulation controls.
// Holds pending delays and blocked toggles; recomputes simulation on every change.
// No Firestore interaction until apply() is called.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../core/utils/score_utils.dart';
import 'project_provider.dart';

class WhatIfState {
  /// Per-task delay overrides: taskId → delay days
  final Map<String, int> pendingDelays;

  /// Per-task blocked overrides
  final Set<String> blockedTasks;

  /// Recomputed result (null = no changes yet)
  final WhatIfResult? result;

  /// Whether we've made changes from baseline
  final bool isDirty;

  const WhatIfState({
    this.pendingDelays = const {},
    this.blockedTasks = const {},
    this.result,
    this.isDirty = false,
  });

  WhatIfState copyWith({
    Map<String, int>? pendingDelays,
    Set<String>? blockedTasks,
    WhatIfResult? result,
    bool? isDirty,
  }) {
    return WhatIfState(
      pendingDelays: pendingDelays ?? this.pendingDelays,
      blockedTasks: blockedTasks ?? this.blockedTasks,
      result: result ?? this.result,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

class WhatIfResult {
  final double originalScore;
  final double newScore;
  final int totalDelayDays;
  final int affectedTaskCount;
  final List<TaskModel> updatedTasks;

  const WhatIfResult({
    required this.originalScore,
    required this.newScore,
    required this.totalDelayDays,
    required this.affectedTaskCount,
    required this.updatedTasks,
  });

  double get scoreDelta => newScore - originalScore;
}

class WhatIfNotifier extends StateNotifier<WhatIfState> {
  final FirestoreService _fs;
  List<TaskModel> _baseTasks = [];

  WhatIfNotifier(this._fs) : super(const WhatIfState());

  /// Initialize with current tasks
  void initialize(List<TaskModel> tasks) {
    _baseTasks = List.from(tasks);
    // Initialize pending delays from current task delays
    final delays = <String, int>{};
    for (final t in tasks) {
      delays[t.id] = t.delayDays;
    }
    state = WhatIfState(pendingDelays: delays);
  }

  /// Update delay for a specific task
  void setDelay(String taskId, int days) {
    final newDelays = Map<String, int>.from(state.pendingDelays);
    newDelays[taskId] = days;
    state = state.copyWith(pendingDelays: newDelays, isDirty: true);
    _recompute();
  }

  /// Toggle blocked status for a task
  void toggleBlocked(String taskId) {
    final newBlocked = Set<String>.from(state.blockedTasks);
    if (newBlocked.contains(taskId)) {
      newBlocked.remove(taskId);
    } else {
      newBlocked.add(taskId);
    }
    state = state.copyWith(blockedTasks: newBlocked, isDirty: true);
    _recompute();
  }

  /// Reset everything to current baseline
  void resetAll() {
    initialize(_baseTasks);
  }

  /// Recompute the what-if scenario
  void _recompute() {
    final originalScore = computeScore(_baseTasks);

    // Apply all pending changes to create a hypothetical task list
    final updatedTasks = _baseTasks.map((t) {
      final newDelay = state.pendingDelays[t.id] ?? t.delayDays;
      final isBlocked = state.blockedTasks.contains(t.id);
      return t.copyWith(
        delayDays: newDelay,
        status: isBlocked ? TaskStatus.blocked : t.status,
      );
    }).toList();

    final newScore = computeScore(updatedTasks);
    final totalDelay =
        updatedTasks.fold<int>(0, (sum, t) => sum + t.delayDays);
    final affectedCount = updatedTasks.where((t) {
      final base = _baseTasks.firstWhere((b) => b.id == t.id);
      return t.delayDays != base.delayDays || t.status != base.status;
    }).length;

    state = state.copyWith(
      result: WhatIfResult(
        originalScore: originalScore,
        newScore: newScore,
        totalDelayDays: totalDelay,
        affectedTaskCount: affectedCount,
        updatedTasks: updatedTasks,
      ),
    );
  }

  /// Apply all changes to Firestore
  Future<bool> applyChanges(String projectId) async {
    if (state.result == null) return false;

    try {
      for (final task in state.result!.updatedTasks) {
        final base = _baseTasks.firstWhere((b) => b.id == task.id);
        if (task.delayDays != base.delayDays || task.status != base.status) {
          await _fs.updateTaskDelay(
            projectId: projectId,
            taskId: task.id,
            delayDays: task.delayDays,
            allTasks: state.result!.updatedTasks,
          );
        }
      }
      // Refresh baseline
      _baseTasks = state.result!.updatedTasks;
      state = state.copyWith(isDirty: false);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final whatIfNotifierProvider =
    StateNotifierProvider<WhatIfNotifier, WhatIfState>((ref) {
  return WhatIfNotifier(ref.watch(firestoreServiceProvider));
});
