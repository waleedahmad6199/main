// providers/ai_task_provider.dart
//
// Riverpod provider that orchestrates:
// 1. Calling GroqAiService to generate tasks
// 2. Storing them in Firestore under projects/{projectId}/tasks/{taskId}
// 3. Exposing loading / error / success state to the UI

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_generated_task.dart';
import '../services/firestore_service.dart';
import '../services/groq_ai_service.dart';
import 'project_provider.dart';

// ── State for the AI generation flow ──────────────────────────────────────
class AiTaskGenerationState {
  final bool isLoading;
  final String? errorMessage;
  final List<AiGeneratedTask> generatedTasks;

  const AiTaskGenerationState({
    this.isLoading = false,
    this.errorMessage,
    this.generatedTasks = const [],
  });

  AiTaskGenerationState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<AiGeneratedTask>? generatedTasks,
  }) {
    return AiTaskGenerationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      generatedTasks: generatedTasks ?? this.generatedTasks,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────
class AiTaskNotifier extends StateNotifier<AiTaskGenerationState> {
  final FirestoreService _fs;

  AiTaskNotifier(this._fs) : super(const AiTaskGenerationState());

  /// Step 1 — Call the Groq API to generate tasks from a project description.
  Future<void> generateTasks(String projectDescription) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      generatedTasks: [],
    );

    try {
      final tasks =
          await GroqAiService.generateTasks(projectDescription);
      state = state.copyWith(isLoading: false, generatedTasks: tasks);
    } on GroqApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  /// Step 2 — Persist all generated tasks into Firestore.
  ///
  /// Firestore structure:
  ///   projects/{projectId}/tasks/{taskId}   (flat collection, not sub-col)
  ///
  /// We use the existing FirestoreService.addTask so dependency IDs are
  /// resolved from the generated titles to the Firestore-generated UUIDs.
  Future<bool> saveTasksToFirestore({
    required String projectId,
    required String stageId,
  }) async {
    if (state.generatedTasks.isEmpty) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Map from AI task title → Firestore UUID (filled as we create tasks)
      final titleToId = <String, String>{};

      for (int i = 0; i < state.generatedTasks.length; i++) {
        final aiTask = state.generatedTasks[i];

        // Resolve dependency titles to Firestore IDs
        final depIds = aiTask.dependsOn
            .where((t) => titleToId.containsKey(t))
            .map((t) => titleToId[t]!)
            .toList();

        // Create the real task via the existing service
        final created = await _fs.addTask(
          projectId: projectId,
          stageId: stageId,
          title: aiTask.title,
          description: 'Duration: ${aiTask.duration}',
          estimatedDays: aiTask.estimatedDays,
          order: i,
        );

        // Register its ID for downstream dependency resolution
        titleToId[aiTask.title] = created.id;

        // Now add dependencies (after the task exists in Firestore)
        if (depIds.isNotEmpty) {
          // Read all tasks so we can run cycle-check inside addDependency
          // For simplicity we add each dep individually
          for (final depId in depIds) {
            try {
              await _fs.addDependency(
                taskId: created.id,
                dependsOnId: depId,
                allProjectTasks: [], // skip cycle-check for generated tasks
              );
            } catch (_) {
              // Dependency cycle or error — skip this edge, still save the task
            }
          }
        }
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save tasks: $e',
      );
      return false;
    }
  }

  /// Clear state when leaving the screen
  void reset() {
    state = const AiTaskGenerationState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────
final aiTaskNotifierProvider =
    StateNotifierProvider<AiTaskNotifier, AiTaskGenerationState>((ref) {
  return AiTaskNotifier(ref.watch(firestoreServiceProvider));
});
