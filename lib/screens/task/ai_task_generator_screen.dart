// screens/task/ai_task_generator_screen.dart
//
// UI for the AI task generation feature.
// - TextField for project description
// - "Generate Tasks" button
// - ListView showing generated tasks with dependencies
// - "Save to Firestore" button to persist

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ai_generated_task.dart';
import '../../providers/ai_task_provider.dart';

class AiTaskGeneratorScreen extends ConsumerStatefulWidget {
  /// The project these tasks will be saved to
  final String projectId;

  /// The default stage to assign generated tasks to (e.g. "stage_todo")
  final String defaultStageId;

  const AiTaskGeneratorScreen({
    super.key,
    required this.projectId,
    this.defaultStageId = 'stage_todo',
  });

  @override
  ConsumerState<AiTaskGeneratorScreen> createState() =>
      _AiTaskGeneratorScreenState();
}

class _AiTaskGeneratorScreenState
    extends ConsumerState<AiTaskGeneratorScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _onGenerate() async {
    FocusScope.of(context).unfocus();
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnack('Please enter a project description.');
      return;
    }
    await ref.read(aiTaskNotifierProvider.notifier).generateTasks(text);
  }

  Future<void> _onSave() async {
    final success =
        await ref.read(aiTaskNotifierProvider.notifier).saveTasksToFirestore(
              projectId: widget.projectId,
              stageId: widget.defaultStageId,
            );
    if (!mounted) return;
    if (success) {
      _showSnack('Tasks saved to Firestore ✓');
      Navigator.of(context).pop(); // go back to task list
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiTaskNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Task Generator'),
        actions: [
          // Show save button only when tasks have been generated
          if (state.generatedTasks.isNotEmpty && !state.isLoading)
            TextButton.icon(
              onPressed: _onSave,
              icon: const Icon(Icons.save_rounded, size: 20),
              label: const Text('Save All'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Input area ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Describe your project',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. Build a mobile e-commerce app with user '
                        'authentication, product catalog, shopping cart, '
                        'and payment integration…',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: state.isLoading ? null : _onGenerate,
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      state.isLoading
                          ? 'Generating…'
                          : 'Generate Tasks with AI',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Error banner ─────────────────────────────────────────────
          if (state.errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),

          // ── Task list ────────────────────────────────────────────────
          if (state.generatedTasks.isNotEmpty) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded,
                      color: colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${state.generatedTasks.length} tasks generated',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: state.generatedTasks.length,
                itemBuilder: (context, index) {
                  final task = state.generatedTasks[index];
                  return _TaskCard(
                    index: index + 1,
                    task: task,
                  );
                },
              ),
            ),
          ] else if (!state.isLoading && state.errorMessage == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'Enter a project description above\n'
                      'and tap Generate to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Single task card widget ───────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final int index;
  final AiGeneratedTask task;

  const _TaskCard({required this.index, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Duration chip
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 16, color: colorScheme.secondary),
                const SizedBox(width: 4),
                Text(
                  task.duration,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${task.estimatedDays}d',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),

            // Dependency chips
            if (task.dependsOn.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Icon(Icons.account_tree_rounded,
                      size: 14, color: Colors.grey),
                  ...task.dependsOn.map(
                    (dep) => Chip(
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      label: Text(dep, style: const TextStyle(fontSize: 11)),
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
