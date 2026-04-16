// models/stage_model.dart

class StageModel {
  final String id;
  final String name;
  final int order; // 0-based display order
  final String color; // hex color for UI

  const StageModel({
    required this.id,
    required this.name,
    required this.order,
    required this.color,
  });

  factory StageModel.fromMap(Map<String, dynamic> map) {
    return StageModel(
      id: map['id'] as String,
      name: map['name'] as String,
      order: map['order'] as int? ?? 0,
      color: map['color'] as String? ?? '#607D8B',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'color': color,
    };
  }

  /// Default stages for a new project
  static List<StageModel> defaults() {
    return const [
      StageModel(id: 'stage_todo',        name: 'To Do',       order: 0, color: '#607D8B'),
      StageModel(id: 'stage_inprogress',  name: 'In Progress', order: 1, color: '#1976D2'),
      StageModel(id: 'stage_review',      name: 'Review',      order: 2, color: '#F57C00'),
      StageModel(id: 'stage_done',        name: 'Done',        order: 3, color: '#388E3C'),
    ];
  }

  StageModel copyWith({String? id, String? name, int? order, String? color}) {
    return StageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      color: color ?? this.color,
    );
  }
}