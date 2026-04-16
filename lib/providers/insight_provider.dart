// providers/insight_provider.dart
//
// Computes project insights from task data via the InsightEngine.
// Refreshes automatically when tasks change.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/insight_model.dart';
import '../services/insight_engine.dart';
import 'task_provider.dart';

/// Provides computed insights for a project.
/// Automatically recomputes when the project's tasks change.
final insightProvider =
    Provider.family<List<ProjectInsight>, String>((ref, projectId) {
  final tasksAsync = ref.watch(tasksProvider(projectId));
  return tasksAsync.when(
    data: (tasks) => InsightEngine.computeInsights(tasks),
    loading: () => [],
    error: (_, __) => [],
  );
});
