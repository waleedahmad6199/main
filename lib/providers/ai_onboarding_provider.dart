// providers/ai_onboarding_provider.dart
//
// Orchestrates the AI-powered onboarding flow:
// 1. Generate a complete project plan (tasks, risks, milestones)
// 2. Expose plan to UI for animated display
// 3. Save everything to Firestore

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_project_plan.dart';
import '../services/firestore_service.dart';
import '../services/groq_ai_service.dart';
import 'project_provider.dart';

class AiOnboardingState {
  final bool isLoading;
  final String? errorMessage;
  final AiProjectPlan? plan;
  final bool isSaving;
  final String loadingMessage;

  const AiOnboardingState({
    this.isLoading = false,
    this.errorMessage,
    this.plan,
    this.isSaving = false,
    this.loadingMessage = 'Analyzing your project...',
  });

  AiOnboardingState copyWith({
    bool? isLoading,
    String? errorMessage,
    AiProjectPlan? plan,
    bool? isSaving,
    String? loadingMessage,
  }) {
    return AiOnboardingState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      plan: plan ?? this.plan,
      isSaving: isSaving ?? this.isSaving,
      loadingMessage: loadingMessage ?? this.loadingMessage,
    );
  }
}

class AiOnboardingNotifier extends StateNotifier<AiOnboardingState> {
  final FirestoreService _fs;

  AiOnboardingNotifier(this._fs) : super(const AiOnboardingState());

  Future<void> generatePlan(String projectDescription) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      loadingMessage: '🧠 Analyzing your project...',
    );

    // Simulate phased loading messages for UX
    Future.delayed(const Duration(seconds: 2), () {
      if (state.isLoading) {
        state = state.copyWith(loadingMessage: '📋 Generating tasks...');
      }
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (state.isLoading) {
        state = state.copyWith(loadingMessage: '⚠️ Identifying risks...');
      }
    });
    Future.delayed(const Duration(seconds: 6), () {
      if (state.isLoading) {
        state = state.copyWith(loadingMessage: '🎯 Setting milestones...');
      }
    });

    try {
      final plan =
          await GroqAiService.generateProjectPlan(projectDescription);
      state = state.copyWith(isLoading: false, plan: plan);
    } on GroqApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  Future<bool> savePlanToFirestore({
    required String projectId,
    required String stageId,
  }) async {
    if (state.plan == null) return false;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final titleToId = <String, String>{};

      for (int i = 0; i < state.plan!.tasks.length; i++) {
        final aiTask = state.plan!.tasks[i];

        final depIds = aiTask.dependsOn
            .where((t) => titleToId.containsKey(t))
            .map((t) => titleToId[t]!)
            .toList();

        final created = await _fs.addTask(
          projectId: projectId,
          stageId: stageId,
          title: aiTask.title,
          description: 'Duration: ${aiTask.duration}',
          estimatedDays: aiTask.estimatedDays,
          order: i,
        );

        titleToId[aiTask.title] = created.id;

        for (final depId in depIds) {
          try {
            await _fs.addDependency(
              taskId: created.id,
              dependsOnId: depId,
              allProjectTasks: [],
            );
          } catch (_) {}
        }
      }

      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save plan: $e',
      );
      return false;
    }
  }

  void reset() {
    state = const AiOnboardingState();
  }
}

final aiOnboardingNotifierProvider =
    StateNotifierProvider<AiOnboardingNotifier, AiOnboardingState>((ref) {
  return AiOnboardingNotifier(ref.watch(firestoreServiceProvider));
});
