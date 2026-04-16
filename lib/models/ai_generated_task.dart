// models/ai_generated_task.dart
//
// Lightweight model representing a single task returned by the Groq AI API.
// This is intentionally separate from TaskModel so we can parse, validate,
// and display before persisting to Firestore.

class AiGeneratedTask {
  final String title;
  final String duration; // e.g. "3 days", "1 week"
  final List<String> dependsOn; // titles of tasks this depends on

  const AiGeneratedTask({
    required this.title,
    required this.duration,
    required this.dependsOn,
  });

  /// Parse a single task from the AI JSON response.
  /// Returns null instead of throwing if the map is malformed.
  factory AiGeneratedTask.fromJson(Map<String, dynamic> json) {
    // Capture the raw value first
    final rawDependsOn = json['depends_on'];

    List<String> parsedDependencies = [];

    if (rawDependsOn is List) {
      parsedDependencies = rawDependsOn
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawDependsOn is String && rawDependsOn.isNotEmpty) {
      // Handle the case where the AI sends a comma-separated string or a single string
      parsedDependencies = rawDependsOn
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return AiGeneratedTask(
      title: json['title']?.toString().trim() ?? 'Untitled Task',
      duration: json['duration']?.toString().trim() ?? '1 day',
      dependsOn: parsedDependencies,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'duration': duration,
        'depends_on': dependsOn,
      };

  /// Best-effort conversion of the duration string to an integer day count.
  /// Examples: "3 days" → 3, "1 week" → 7, "2 weeks" → 14, "1 month" → 30
  int get estimatedDays {
    final lower = duration.toLowerCase();
    final numMatch = RegExp(r'(\d+)').firstMatch(lower);
    final n = numMatch != null ? int.tryParse(numMatch.group(1)!) ?? 1 : 1;

    if (lower.contains('week')) return n * 7;
    if (lower.contains('month')) return n * 30;
    if (lower.contains('hour')) return 1; // minimum 1 day
    return n; // default: treat numeric value as days
  }

  @override
  String toString() =>
      'AiGeneratedTask(title: $title, duration: $duration, dependsOn: $dependsOn)';
}
