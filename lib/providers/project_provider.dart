// providers/project_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

// ── Service singleton ─────────────────────────────────────────────────────
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

// ── Selected project ID ────────────────────────────────────────────────────
final selectedProjectIdProvider = StateProvider<String?>((ref) => null);

// ── Projects list for current user ────────────────────────────────────────
final projectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref.watch(firestoreServiceProvider).projectsForUser(user.id);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ── Single project stream ─────────────────────────────────────────────────
final projectStreamProvider =
    StreamProvider.family<ProjectModel?, String>((ref, projectId) {
  return ref.watch(firestoreServiceProvider).projectStream(projectId);
});

// ── Project Notifier (create, update) ────────────────────────────────────
class ProjectNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _fs;
  final String _userId;

  ProjectNotifier(this._fs, this._userId) : super(const AsyncValue.data(null));

  Future<ProjectModel?> createProject({
    required String title,
    required String description,
  }) async {
    state = const AsyncValue.loading();
    try {
      final project = await _fs.createProject(
        title: title,
        description: description,
        ownerId: _userId,
      );

      // ✅ Check if the provider is still alive before updating state
      if (!mounted) return project;

      state = const AsyncValue.data(null);
      return project;
    } catch (e, st) {
      // ✅ Check if the provider is still alive before throwing an error state
      if (!mounted) return null;

      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateProject({
    required String projectId,
    String? title,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _fs.updateProject(
        projectId: projectId,
        title: title,
        description: description,
      );
      if (mounted) state = const AsyncValue.data(null);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteProject(String projectId) async {
    state = const AsyncValue.loading();
    try {
      await _fs.deleteProject(projectId);
      if (mounted) state = const AsyncValue.data(null);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }
}

final projectNotifierProvider =
    StateNotifierProvider<ProjectNotifier, AsyncValue<void>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return ProjectNotifier(
    ref.watch(firestoreServiceProvider),
    user?.id ?? '',
  );
});
