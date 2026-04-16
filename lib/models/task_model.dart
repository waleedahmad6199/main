// models/task_model.dart

enum TaskStatus { pending, inProgress, blocked, completed }

class TaskModel {
  final String id;
  final String projectId;
  final String stageId;
  final String title;
  final String description;
  final String? assigneeId;

  /// IDs of tasks that must complete BEFORE this task can start
  final List<String> dependencyIds;

  final TaskStatus status;
  final int estimatedDays;
  final int actualDays;

  /// Delay added to this task (either directly or via propagation)
  final int delayDays;

  /// How many times this task was sent back for rework
  final int reworkCount;

  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    required this.projectId,
    required this.stageId,
    required this.title,
    required this.description,
    this.assigneeId,
    required this.dependencyIds,
    required this.status,
    required this.estimatedDays,
    required this.actualDays,
    required this.delayDays,
    required this.reworkCount,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total days = estimated + delay
  int get totalDays => estimatedDays + delayDays;

  /// Delay ratio: how much of the schedule is delayed
  double get delayRatio =>
      estimatedDays == 0 ? 0 : delayDays / estimatedDays;

  bool get isBlocked => status == TaskStatus.blocked;
  bool get isCompleted => status == TaskStatus.completed;

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      projectId: map['projectId']?.toString() ?? '',
      stageId: map['stageId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      assigneeId: map['assigneeId']?.toString(),
      dependencyIds: (map['dependencyIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: _statusFromString(map['status']?.toString() ?? 'pending'),
      estimatedDays: (map['estimatedDays'] as num?)?.toInt() ?? 1,
      actualDays: (map['actualDays'] as num?)?.toInt() ?? 0,
      delayDays: (map['delayDays'] as num?)?.toInt() ?? 0,
      reworkCount: (map['reworkCount'] as num?)?.toInt() ?? 0,
      order: (map['order'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'stageId': stageId,
      'title': title,
      'description': description,
      'assigneeId': assigneeId,
      'dependencyIds': dependencyIds,
      'status': status.name,
      'estimatedDays': estimatedDays,
      'actualDays': actualDays,
      'delayDays': delayDays,
      'reworkCount': reworkCount,
      'order': order,
      'updatedAt': DateTime.now(),
    };
  }

  static TaskStatus _statusFromString(String s) {
    switch (s) {
      case 'inProgress':
        return TaskStatus.inProgress;
      case 'blocked':
        return TaskStatus.blocked;
      case 'completed':
        return TaskStatus.completed;
      default:
        return TaskStatus.pending;
    }
  }

  TaskModel copyWith({
    String? id,
    String? projectId,
    String? stageId,
    String? title,
    String? description,
    String? assigneeId,
    List<String>? dependencyIds,
    TaskStatus? status,
    int? estimatedDays,
    int? actualDays,
    int? delayDays,
    int? reworkCount,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      stageId: stageId ?? this.stageId,
      title: title ?? this.title,
      description: description ?? this.description,
      assigneeId: assigneeId ?? this.assigneeId,
      dependencyIds: dependencyIds ?? this.dependencyIds,
      status: status ?? this.status,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      actualDays: actualDays ?? this.actualDays,
      delayDays: delayDays ?? this.delayDays,
      reworkCount: reworkCount ?? this.reworkCount,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}