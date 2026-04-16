// models/ai_project_plan.dart
//
// Enhanced AI response model for the AI-powered onboarding experience.
// Contains tasks, risks, milestones, and timeline — a complete project plan.

import 'ai_generated_task.dart';

class AiProjectPlan {
  final List<AiGeneratedTask> tasks;
  final List<AiRiskItem> risks;
  final String estimatedTimeline;
  final List<AiMilestone> milestones;

  const AiProjectPlan({
    required this.tasks,
    required this.risks,
    required this.estimatedTimeline,
    required this.milestones,
  });

  factory AiProjectPlan.fromJson(Map<String, dynamic> json) {
    // Parse tasks
    final rawTasks = json['tasks'] as List? ?? [];
    final tasks = rawTasks
        .whereType<Map<String, dynamic>>()
        .map((e) => AiGeneratedTask.fromJson(e))
        .toList();

    // Parse risks
    final rawRisks = json['risks'] as List? ?? [];
    final risks = rawRisks
        .whereType<Map<String, dynamic>>()
        .map((e) => AiRiskItem.fromJson(e))
        .toList();

    // Parse milestones
    final rawMilestones = json['milestones'] as List? ?? [];
    final milestones = rawMilestones
        .whereType<Map<String, dynamic>>()
        .map((e) => AiMilestone.fromJson(e))
        .toList();

    return AiProjectPlan(
      tasks: tasks,
      risks: risks,
      estimatedTimeline:
          (json['estimated_timeline']?.toString()) ?? 'Unknown',
      milestones: milestones,
    );
  }
}

class AiRiskItem {
  final String title;
  final String severity; // "high", "medium", "low"
  final String mitigation;

  const AiRiskItem({
    required this.title,
    required this.severity,
    required this.mitigation,
  });

  factory AiRiskItem.fromJson(Map<String, dynamic> json) {
    return AiRiskItem(
      title: (json['title']?.toString()) ?? 'Unknown Risk',
      severity: (json['severity']?.toString()) ?? 'medium',
      mitigation: (json['mitigation']?.toString()) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'severity': severity,
        'mitigation': mitigation,
      };

  bool get isHigh => severity.toLowerCase() == 'high';
  bool get isMedium => severity.toLowerCase() == 'medium';
  bool get isLow => severity.toLowerCase() == 'low';
}

class AiMilestone {
  final String title;
  final String targetWeek;
  final List<String> taskTitles;

  const AiMilestone({
    required this.title,
    required this.targetWeek,
    required this.taskTitles,
  });

  factory AiMilestone.fromJson(Map<String, dynamic> json) {
    return AiMilestone(
      title: (json['title']?.toString()) ?? 'Milestone',
      targetWeek: (json['target_week']?.toString()) ?? '',
      taskTitles: (json['task_titles'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'target_week': targetWeek,
        'task_titles': taskTitles,
      };
}
