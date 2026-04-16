// services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/score_utils.dart';
import '../models/project_model.dart';
import '../models/simulation_log_model.dart';
import '../models/stage_model.dart';
import '../models/task_model.dart';
import 'simulation_engine.dart';

const _uuid = Uuid();

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────────────────────────────────
  // PROJECTS
  // ──────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');

  /// Create a new project with default stages
  Future<ProjectModel> createProject({
    required String title,
    required String description,
    required String ownerId,
  }) async {
    final id = _uuid.v4();
    final project = ProjectModel(
      id: id,
      title: title,
      description: description,
      ownerId: ownerId,
      memberIds: [ownerId],
      stages: StageModel.defaults(),
      status: ProjectStatus.active,
      efficiencyScore: 100.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _projects.doc(id).set({
      ...project.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Add project to user's projectIds
    await _db.collection('users').doc(ownerId).update({
      'projectIds': FieldValue.arrayUnion([id]),
    });
    return project;
  }

  Stream<List<ProjectModel>> projectsForUser(String userId) {
    return _projects
        .where('memberIds', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => ProjectModel.fromMap(d.data(), d.id))
        .toList());
  }

  Stream<ProjectModel?> projectStream(String projectId) {
    return _projects.doc(projectId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ProjectModel.fromMap(snap.data()!, snap.id);
    });
  }

  Future<void> updateProject({
    required String projectId,
    String? title,
    String? description,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;

    await _projects.doc(projectId).update(updates);
  }

  Future<void> deleteProject(String projectId) async {
    // Delete all tasks associated with the project
    final tasksSnap = await _tasks.where('projectId', isEqualTo: projectId).get();
    final batch = _db.batch();
    for (final doc in tasksSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete all simulation logs associated with the project
    final simsSnap = await _simulations.where('projectId', isEqualTo: projectId).get();
    for (final doc in simsSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete the project itself
    batch.delete(_projects.doc(projectId));

    // Remove project from users' projectIds
    final usersSnap = await _db
        .collection('users')
        .where('projectIds', arrayContains: projectId)
        .get();
    for (final doc in usersSnap.docs) {
      batch.update(doc.reference, {
        'projectIds': FieldValue.arrayRemove([projectId]),
      });
    }

    await batch.commit();
  }

  Future<void> updateProjectScore(String projectId, double score) async {
    await _projects.doc(projectId).update({
      'efficiencyScore': score,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addMemberToProject(String projectId, String userId) async {
    await _projects.doc(projectId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    await _db.collection('users').doc(userId).update({
      'projectIds': FieldValue.arrayUnion([projectId]),
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TASKS
  // ──────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('tasks');

  Future<TaskModel> addTask({
    required String projectId,
    required String stageId,
    required String title,
    required String description,
    required int estimatedDays,
    String? assigneeId,
    int order = 0,
  }) async {
    final id = _uuid.v4();
    final task = TaskModel(
      id: id,
      projectId: projectId,
      stageId: stageId,
      title: title,
      description: description,
      assigneeId: assigneeId,
      dependencyIds: const [],
      status: TaskStatus.pending,
      estimatedDays: estimatedDays,
      actualDays: 0,
      delayDays: 0,
      reworkCount: 0,
      order: order,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _tasks.doc(id).set({
      ...task.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return task;
  }

  /// Move a task to a different stage
  Future<void> updateTaskStage(String taskId, String newStageId) async {
    await _tasks.doc(taskId).update({
      'stageId': newStageId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    await _tasks.doc(taskId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a dependency edge: [taskId] now depends on [dependsOnId]
  /// Throws if adding this dependency would create a cycle.
  Future<void> addDependency({
    required String taskId,
    required String dependsOnId,
    required List<TaskModel> allProjectTasks,
  }) async {
    // Cycle check before writing
    final wouldCycle = _wouldCreateCycle(
      fromId: dependsOnId,
      toId: taskId,
      tasks: allProjectTasks,
    );
    if (wouldCycle) {
      throw Exception(
          'Adding this dependency would create a cycle in the task graph.');
    }
    await _tasks.doc(taskId).update({
      'dependencyIds': FieldValue.arrayUnion([dependsOnId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeDependency({
    required String taskId,
    required String dependsOnId,
  }) async {
    await _tasks.doc(taskId).update({
      'dependencyIds': FieldValue.arrayRemove([dependsOnId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<TaskModel>> tasksForProject(String projectId) {
    return _tasks
        .where('projectId', isEqualTo: projectId)
        .orderBy('order')
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => TaskModel.fromMap(d.data(), d.id)).toList());
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SIMULATION
  // ──────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _simulations =>
      _db.collection('simulations');

  /// Run simulation preview – compute results and save a log entry,
  /// but do NOT persist task/project changes.
  Future<SimulationLogModel> runSimulationPreview({
    required String projectId,
    required String taskId,
    required int delayDays,
    required List<TaskModel> allTasks,
    required String createdBy,
  }) async {
    // Execute pure-logic simulation
    final result = SimulationEngine.runSimulation(
      taskId: taskId,
      delayDays: delayDays,
      allTasks: allTasks,
    );

    // Save simulation log (but do NOT persist task changes)
    final triggerTask = allTasks.firstWhere((t) => t.id == taskId);
    final logId = _uuid.v4();
    final log = SimulationLogModel(
      id: logId,
      projectId: projectId,
      triggeredByTaskId: taskId,
      triggeredByTaskTitle: triggerTask.title,
      delayApplied: delayDays,
      affectedTaskIds: result.affectedTaskIds,
      impactSummary: result.impactEntries,
      scoreBefore: result.scoreBefore,
      scoreAfter: result.scoreAfter,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await _simulations.doc(logId).set({
      ...log.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return log;
  }

  /// Apply a simulation: persist all task delay changes + project score.
  Future<void> applySimulationResult({
    required String projectId,
    required String taskId,
    required int delayDays,
    required List<TaskModel> allTasks,
  }) async {
    final result = SimulationEngine.runSimulation(
      taskId: taskId,
      delayDays: delayDays,
      allTasks: allTasks,
    );

    // Persist changed tasks in a batch write
    final batch = _db.batch();
    for (final task in result.changedTasks) {
      batch.update(_tasks.doc(task.id), {
        ...task.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Update project efficiency score
    batch.update(_projects.doc(projectId), {
      'efficiencyScore': result.scoreAfter,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Save simulation log (for history)
    final logId = _uuid.v4();
    final triggerTask = allTasks.firstWhere((t) => t.id == taskId, orElse: () => allTasks.first);
    final log = SimulationLogModel(
      id: logId,
      projectId: projectId,
      triggeredByTaskId: taskId,
      triggeredByTaskTitle: triggerTask.title,
      delayApplied: delayDays,
      affectedTaskIds: result.affectedTaskIds,
      impactSummary: result.impactEntries,
      scoreBefore: result.scoreBefore,
      scoreAfter: result.scoreAfter,
      createdBy: "applied", // Optionally, pass userId if available
      createdAt: DateTime.now(),
    );
    await _simulations.doc(logId).set({
      ...log.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Set/remove delay on a specific task and recalculate the project score.
  Future<void> updateTaskDelay({
    required String projectId,
    required String taskId,
    required int delayDays,
    required List<TaskModel> allTasks,
  }) async {
    final batch = _db.batch();
    batch.update(_tasks.doc(taskId), {
      'delayDays': delayDays,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Recalculate score with updated delay
    final updatedTasks = allTasks.map((t) {
      if (t.id == taskId) return t.copyWith(delayDays: delayDays);
      return t;
    }).toList();
    final newScore = computeScore(updatedTasks);

    batch.update(_projects.doc(projectId), {
      'efficiencyScore': newScore,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Stream<List<SimulationLogModel>> simulationsForProject(String projectId) {
    return _simulations
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => SimulationLogModel.fromMap(d.data(), d.id))
        .toList());
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Local cycle-check before Firestore write (avoids storing invalid state)
  bool _wouldCreateCycle({
    required String fromId,
    required String toId,
    required List<TaskModel> tasks,
  }) {
    final adj = <String, List<String>>{for (final t in tasks) t.id: []};
    for (final task in tasks) {
      for (final depId in task.dependencyIds) {
        adj[depId] ??= [];
        adj[depId]!.add(task.id);
      }
    }
    adj[fromId] ??= [];
    adj[fromId]!.add(toId);

    final visited = <String>{};
    bool canReach(String cur) {
      if (cur == fromId) return true;
      if (visited.contains(cur)) return false;
      visited.add(cur);
      return (adj[cur] ?? []).any(canReach);
    }

    return canReach(toId);
  }

  Future<void> renameTask({
    required String taskId,
    required String newTitle,
  }) async {
    await _tasks.doc(taskId).update({
      'title': newTitle,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTask(String taskId) async {
    await _tasks.doc(taskId).delete();
  }
}