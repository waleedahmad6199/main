// models/simulation_log_model.dart

class ImpactEntry {
  final String taskId;
  final String taskTitle;
  final int delayAdded; // days of delay propagated to this task
  final bool wasBlocked;

  const ImpactEntry({
    required this.taskId,
    required this.taskTitle,
    required this.delayAdded,
    required this.wasBlocked,
  });

  factory ImpactEntry.fromMap(Map<String, dynamic> m) => ImpactEntry(
    taskId: m['taskId']?.toString() ?? '',
    taskTitle: m['taskTitle']?.toString() ?? '',
    delayAdded: (m['delayAdded'] as num?)?.toInt() ?? 0,
    wasBlocked: m['wasBlocked'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'taskId': taskId,
    'taskTitle': taskTitle,
    'delayAdded': delayAdded,
    'wasBlocked': wasBlocked,
  };
}

class SimulationLogModel {
  final String id;
  final String projectId;
  final String triggeredByTaskId;
  final String triggeredByTaskTitle;
  final int delayApplied; // days applied to the trigger task
  final List<String> affectedTaskIds;
  final List<ImpactEntry> impactSummary;
  final double scoreBefore;
  final double scoreAfter;
  final String createdBy; // userId
  final DateTime createdAt;

  const SimulationLogModel({
    required this.id,
    required this.projectId,
    required this.triggeredByTaskId,
    required this.triggeredByTaskTitle,
    required this.delayApplied,
    required this.affectedTaskIds,
    required this.impactSummary,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.createdBy,
    required this.createdAt,
  });

  double get scoreDelta => scoreAfter - scoreBefore;

  factory SimulationLogModel.fromMap(Map<String, dynamic> map, String id) {
    final rawImpact = map['impactSummary'] as List? ?? [];
    return SimulationLogModel(
      id: id,
      projectId: map['projectId']?.toString() ?? '',
      triggeredByTaskId: map['triggeredByTaskId']?.toString() ?? '',
      triggeredByTaskTitle: map['triggeredByTaskTitle']?.toString() ?? '',
      delayApplied: (map['delayApplied'] as num?)?.toInt() ?? 0,
      affectedTaskIds: List<String>.from(map['affectedTaskIds'] as List? ?? []),
      impactSummary: rawImpact
          .map((e) => ImpactEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      scoreBefore: (map['scoreBefore'] as num?)?.toDouble() ?? 100.0,
      scoreAfter: (map['scoreAfter'] as num?)?.toDouble() ?? 100.0,
      createdBy: map['createdBy']?.toString() ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'triggeredByTaskId': triggeredByTaskId,
      'triggeredByTaskTitle': triggeredByTaskTitle,
      'delayApplied': delayApplied,
      'affectedTaskIds': affectedTaskIds,
      'impactSummary': impactSummary.map((e) => e.toMap()).toList(),
      'scoreBefore': scoreBefore,
      'scoreAfter': scoreAfter,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}