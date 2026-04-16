// models/project_model.dart

import 'stage_model.dart';

enum ProjectStatus { active, completed, archived }

class ProjectModel {
  final String id;
  final String title;
  final String description;
  final String ownerId;
  final List<String> memberIds;
  final List<StageModel> stages;
  final ProjectStatus status;

  /// Cached efficiency score (0–100). Recalculated after each simulation.
  final double efficiencyScore;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.memberIds,
    required this.stages,
    required this.status,
    required this.efficiencyScore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map, String id) {
    final rawStages = map['stages'] as List? ?? [];
    return ProjectModel(
      id: id,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      ownerId: map['ownerId']?.toString() ?? '',
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
      stages: rawStages
          .map((s) => StageModel.fromMap(s as Map<String, dynamic>))
          .toList(),
      status: _statusFromString(map['status']?.toString() ?? 'active'),
      efficiencyScore: (map['efficiencyScore'] as num?)?.toDouble() ?? 100.0,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'stages': stages.map((s) => s.toMap()).toList(),
      'status': status.name,
      'efficiencyScore': efficiencyScore,
      'updatedAt': DateTime.now(),
    };
  }

  static ProjectStatus _statusFromString(String s) {
    switch (s) {
      case 'completed':
        return ProjectStatus.completed;
      case 'archived':
        return ProjectStatus.archived;
      default:
        return ProjectStatus.active;
    }
  }

  ProjectModel copyWith({
    String? id,
    String? title,
    String? description,
    String? ownerId,
    List<String>? memberIds,
    List<StageModel>? stages,
    ProjectStatus? status,
    double? efficiencyScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      stages: stages ?? this.stages,
      status: status ?? this.status,
      efficiencyScore: efficiencyScore ?? this.efficiencyScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}