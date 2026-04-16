// providers/simulation_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/simulation_log_model.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';
import 'project_provider.dart';

// ── Simulation logs stream ────────────────────────────────────────────────
final simulationLogsProvider =
    StreamProvider.family<List<SimulationLogModel>, String>((ref, projectId) {
  return ref.watch(firestoreServiceProvider).simulationsForProject(projectId);
});

// ── Last simulation result (for UI display after running) ─────────────────
final lastSimulationResultProvider =
    StateProvider<SimulationLogModel?>((ref) => null);

// ── Simulation Notifier ───────────────────────────────────────────────────
class SimulationNotifier
    extends StateNotifier<AsyncValue<SimulationLogModel?>> {
  final FirestoreService _fs;
  final String _userId;

  // Store last simulation params so we can apply later
  String? _lastProjectId;
  String? _lastTaskId;
  int? _lastDelayDays;
  List<TaskModel>? _lastAllTasks;

  SimulationNotifier(this._fs, this._userId)
      : super(const AsyncValue.data(null));

  /// Preview only – compute and log, but do NOT persist task changes.
  Future<SimulationLogModel?> runSimulationPreview({
    required String projectId,
    required String taskId,
    required int delayDays,
    required List<TaskModel> allTasks,
  }) async {
    state = const AsyncValue.loading();
    try {
      final log = await _fs.runSimulationPreview(
        projectId: projectId,
        taskId: taskId,
        delayDays: delayDays,
        allTasks: allTasks,
        createdBy: _userId,
      );
      // Store params for potential apply
      _lastProjectId = projectId;
      _lastTaskId = taskId;
      _lastDelayDays = delayDays;
      _lastAllTasks = allTasks;
      state = AsyncValue.data(log);
      return log;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Apply the last previewed simulation to Firestore (persist delays).
  Future<void> applyLastSimulation() async {
    if (_lastProjectId == null ||
        _lastTaskId == null ||
        _lastDelayDays == null ||
        _lastAllTasks == null) {
      return;
    }
    try {
      await _fs.applySimulationResult(
        projectId: _lastProjectId!,
        taskId: _lastTaskId!,
        delayDays: _lastDelayDays!,
        allTasks: _lastAllTasks!,
      );
      _clearLastSim();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Discard the last simulation preview (don't persist).
  void discardLastSimulation() {
    _clearLastSim();
    state = const AsyncValue.data(null);
  }

  bool get hasPendingSimulation => _lastProjectId != null;

  void _clearLastSim() {
    _lastProjectId = null;
    _lastTaskId = null;
    _lastDelayDays = null;
    _lastAllTasks = null;
  }

  void reset() {
    _clearLastSim();
    state = const AsyncValue.data(null);
  }
}

final simulationNotifierProvider =
    StateNotifierProvider<SimulationNotifier, AsyncValue<SimulationLogModel?>>(
        (ref) {
  final user = ref.watch(currentUserProvider).value;
  return SimulationNotifier(
    ref.watch(firestoreServiceProvider),
    user?.id ?? '',
  );
});
