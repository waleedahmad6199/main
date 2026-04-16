// services/groq_ai_service.dart
//
// Service class that calls the Groq API for:
// 1. Task generation from project description
// 2. Full project plan generation (onboarding)
// 3. Project predictions

import 'dart:convert';
import 'dart:io';

import '../models/ai_generated_task.dart';
import '../models/ai_project_plan.dart';

class GroqAiService {
  // ── Configuration ────────────────────────────────────────────────────────
  // TODO: Replace with your own Groq API key.
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  static const String _model = 'llama-3.3-70b-versatile';

  // ── System prompts ──────────────────────────────────────────────────────
  static const String _taskSystemPrompt =
      'You are a professional project management assistant. '
      'When the user provides a project description, break it down into a list of actionable tasks. '
      'RULES: 1. Return ONLY a valid JSON object with a "tasks" key containing an array of task objects. '
      '2. Each element must have exactly these keys: "title", "duration", "depends_on". '
      '3. Order tasks logically. 4. Provide between 5 and 15 tasks.';

  static const String _planSystemPrompt =
      'You are a senior project manager and risk analyst. '
      'Given a project description, create a COMPLETE project plan. '
      'Return a JSON object with EXACTLY these keys:\n'
      '- "tasks": array of objects with {title, duration, depends_on}\n'
      '- "risks": array of objects with {title, severity ("high"|"medium"|"low"), mitigation}\n'
      '- "milestones": array of objects with {title, target_week, task_titles}\n'
      '- "estimated_timeline": string like "6 weeks"\n'
      'RULES: Provide 8-15 tasks, 3-5 risks, and 2-4 milestones. '
      'Tasks must have realistic durations and logical dependencies. '
      'Risks should be specific and actionable. '
      'Milestones should group related tasks.';

  static const String _predictionSystemPrompt =
      'You are a project risk analyst. Given the project data, provide:\n'
      '1. A completion prediction with estimated finish date and confidence %\n'
      '2. Top 3 risks with severity and mitigation strategies\n'
      '3. Top 3 optimization suggestions that could save time\n'
      'Return as JSON with keys: '
      '"prediction" (object with "summary", "estimated_days_remaining", "confidence_percent", "status" ["on_track"|"at_risk"|"critical"]), '
      '"risks" (array of {title, severity, impact_days, mitigation}), '
      '"optimizations" (array of {title, description, potential_days_saved})';

  // ── Public API ───────────────────────────────────────────────────────────

  /// Sends [projectDescription] to Groq and returns a parsed list of tasks.
  static Future<List<AiGeneratedTask>> generateTasks(
      String projectDescription) async {
    if (projectDescription.trim().isEmpty) {
      throw const GroqApiException('Project description cannot be empty.');
    }

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': _taskSystemPrompt},
        {'role': 'user', 'content': projectDescription},
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.4,
      'max_tokens': 4096,
    });

    final content = await _makeRequest(body);
    return _parseTasks(content);
  }

  /// Generate a complete project plan with tasks, risks, milestones.
  static Future<AiProjectPlan> generateProjectPlan(
      String projectDescription) async {
    if (projectDescription.trim().isEmpty) {
      throw const GroqApiException('Project description cannot be empty.');
    }

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': _planSystemPrompt},
        {'role': 'user', 'content': projectDescription},
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.4,
      'max_tokens': 4096,
    });

    final content = await _makeRequest(body);

    dynamic decoded;
    try {
      decoded = jsonDecode(content.trim());
    } catch (_) {
      throw GroqApiException('AI returned invalid JSON:\n$content');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const GroqApiException('Expected a JSON object from AI.');
    }

    return AiProjectPlan.fromJson(decoded);
  }

  /// Generate project predictions and recommendations.
  static Future<Map<String, dynamic>> generatePrediction(
      String projectContext) async {
    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': _predictionSystemPrompt},
        {'role': 'user', 'content': projectContext},
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.4,
      'max_tokens': 2048,
    });

    final content = await _makeRequest(body);

    dynamic decoded;
    try {
      decoded = jsonDecode(content.trim());
    } catch (_) {
      throw GroqApiException('AI returned invalid JSON:\n$content');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const GroqApiException('Expected a JSON object from AI.');
    }

    return decoded;
  }

  // ── Core HTTP Request ───────────────────────────────────────────────────

  static Future<String> _makeRequest(String body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_baseUrl));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw GroqApiException(
          'Groq API returned status ${response.statusCode}: $responseBody',
        );
      }

      final Map<String, dynamic> envelope;
      try {
        envelope = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (_) {
        throw const GroqApiException('Invalid JSON returned by Groq API.');
      }

      final choices = envelope['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw const GroqApiException('Groq API returned no choices.');
      }

      return (choices[0] as Map<String, dynamic>)['message']['content']
          as String;
    } on GroqApiException {
      rethrow;
    } catch (e) {
      throw GroqApiException('Network error: $e');
    } finally {
      client.close();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static List<AiGeneratedTask> _parseTasks(String content) {
    dynamic decoded;
    try {
      decoded = jsonDecode(content.trim());
    } catch (_) {
      throw GroqApiException('AI returned invalid JSON:\n$content');
    }

    List<dynamic> taskList;

    if (decoded is List) {
      taskList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final inner = decoded['tasks'] ?? decoded.values.first;
      if (inner is List) {
        taskList = inner;
      } else {
        throw const GroqApiException(
          'Unexpected JSON structure — expected an array of tasks.',
        );
      }
    } else {
      throw GroqApiException(
        'Unexpected JSON type: ${decoded.runtimeType}',
      );
    }

    if (taskList.isEmpty) {
      throw const GroqApiException('AI returned an empty task list.');
    }

    return taskList
        .whereType<Map<String, dynamic>>()
        .map((e) => AiGeneratedTask.fromJson(e))
        .toList();
  }
}

class GroqApiException implements Exception {
  final String message;
  const GroqApiException(this.message);

  @override
  String toString() => 'GroqApiException: $message';
}
