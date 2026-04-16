// providers/task_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_model.dart';
import '../services/firestore_service.dart';
import 'project_provider.dart';

// ── Tasks stream for a project ────────────────────────────────────────────
final tasksProvider =
    StreamProvider.family<List<TaskModel>, String>((ref, projectId) {
  return ref.watch(firestoreServiceProvider).tasksForProject(projectId);
});

// ── Task Notifier ─────────────────────────────────────────────────────────
class TaskNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _fs;

  TaskNotifier(this._fs) : super(const AsyncValue.data(null));

  Future<TaskModel?> addTask({
    required String projectId,
    required String stageId,
    required String title,
    required String description,
    required int estimatedDays,
    String? assigneeId,
    int order = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final task = await _fs.addTask(
        projectId: projectId,
        stageId: stageId,
        title: title,
        description: description,
        estimatedDays: estimatedDays,
        assigneeId: assigneeId,
        order: order,
      );
      state = const AsyncValue.data(null);
      return task;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> moveTask(String taskId, String newStageId) async {
    await _fs.updateTaskStage(taskId, newStageId);
  }

  Future<void> addDependency({
    required String taskId,
    required String dependsOnId,
    required List<TaskModel> allTasks,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _fs.addDependency(
        taskId: taskId,
        dependsOnId: dependsOnId,
        allProjectTasks: allTasks,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeDependency({
    required String taskId,
    required String dependsOnId,
  }) async {
    await _fs.removeDependency(taskId: taskId, dependsOnId: dependsOnId);
  }

  /// Set a specific delay on a task (or 0 to remove delay).
  Future<void> updateTaskDelay({
    required String projectId,
    required String taskId,
    required int delayDays,
    required List<TaskModel> allTasks,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _fs.updateTaskDelay(
        projectId: projectId,
        taskId: taskId,
        delayDays: delayDays,
        allTasks: allTasks,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> renameTask({
    required String taskId,
    required String newTitle,
  }) async {
    await _fs.renameTask(taskId: taskId, newTitle: newTitle);
  }

  Future<void> deleteTask(String taskId) async {
    await _fs.deleteTask(taskId);
  }
}

final taskNotifierProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<void>>((ref) {
  return TaskNotifier(ref.watch(firestoreServiceProvider));
});
