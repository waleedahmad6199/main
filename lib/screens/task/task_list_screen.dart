// screens/task/task_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../models/project_model.dart';
import '../../models/stage_model.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import 'ai_task_generator_screen.dart';
import 'task_form_screen.dart';

class TaskListScreen extends ConsumerWidget {
  final String projectId;
  final ProjectModel project;
  const TaskListScreen({super.key, required this.projectId, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(projectId));

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── AI Generate button ─────────────────────────────────
          FloatingActionButton.extended(
            heroTag: 'ai_generate',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AiTaskGeneratorScreen(
                  projectId: projectId,
                ),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('AI Generate'),
            backgroundColor: AppColors.accent,
          ),
          const SizedBox(height: 12),
          // ── Manual add button ──────────────────────────────────
          FloatingActionButton.extended(
            heroTag: 'add_task',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TaskFormScreen(
                  projectId: projectId,
                  stages: project.stages,
                ),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
            backgroundColor: AppColors.primaryLight,
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text('No tasks yet. Add your first task!',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          // Group tasks by stage
          final grouped = <String, List<TaskModel>>{};
          for (final stage in project.stages) {
            grouped[stage.id] = tasks.where((t) => t.stageId == stage.id).toList();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: project.stages.map((stage) {
              final stageTasks = grouped[stage.id] ?? [];
              return _StageSection(
                stage: stage,
                tasks: stageTasks,
                allTasks: tasks,
                projectId: projectId,
                project: project,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StageSection extends ConsumerWidget {
  final StageModel stage;
  final List<TaskModel> tasks;
  final List<TaskModel> allTasks;
  final String projectId;
  final ProjectModel project;

  const _StageSection({
    required this.stage,
    required this.tasks,
    required this.allTasks,
    required this.projectId,
    required this.project,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(int.parse(stage.color.replaceFirst('#', '0xFF')));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(width: 4, height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              Text(stage.name,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${tasks.length}',
                    style: TextStyle(color: color, fontSize: 11)),
              ),
            ],
          ),
        ),
        ...tasks.map((task) => _TaskTile(
          task: task,
          allTasks: allTasks,
          project: project,
          projectId: projectId,
        )),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final TaskModel task;
  final List<TaskModel> allTasks;
  final ProjectModel project;
  final String projectId;

  const _TaskTile({
    required this.task,
    required this.allTasks,
    required this.project,
    required this.projectId,
  });

  Color get _statusColor {
    switch (task.status) {
      case TaskStatus.completed: return AppColors.success;
      case TaskStatus.inProgress: return AppColors.accent;
      case TaskStatus.blocked: return AppColors.blocked;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(task.title,
                    style: Theme.of(context).textTheme.titleMedium)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onSelected: (value) => _handleAction(context, ref, value),
                  itemBuilder: (_) => [
                    ...project.stages.map((s) => PopupMenuItem(
                      value: 'stage_${s.id}',
                      child: Text('Move to ${s.name}'),
                    )),
                    const PopupMenuItem(value: 'dep', child: Text('Add Dependency')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'set_delay', child: Text('Set Delay')),
                    if (task.delayDays > 0)
                      const PopupMenuItem(value: 'remove_delay', child: Text('Remove Delay')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'rename', child: Text('Rename Task')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Task', style: TextStyle(color: AppColors.error))),
                  ],
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(task.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(Icons.schedule, '${task.estimatedDays}d est.'),
                if (task.delayDays > 0) ...[
                  const SizedBox(width: 6),
                  _InfoChip(Icons.warning_amber, '+${task.delayDays}d delay',
                      color: AppColors.warning),
                ],
                if (task.dependencyIds.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _InfoChip(Icons.link, '${task.dependencyIds.length} deps'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String value) {
    if (value.startsWith('stage_')) {
      final stageId = value.replaceFirst('stage_', '');
      ref.read(taskNotifierProvider.notifier).moveTask(task.id, stageId);
    } else if (value == 'dep') {
      _showAddDependencyDialog(context, ref);
    } else if (value == 'set_delay') {
      _showSetDelayDialog(context, ref);
    } else if (value == 'remove_delay') {
      ref.read(taskNotifierProvider.notifier).updateTaskDelay(
        projectId: projectId,
        taskId: task.id,
        delayDays: 0,
        allTasks: allTasks,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delay removed'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (value == 'rename') {
      _showRenameTaskDialog(context, ref);
    } else if (value == 'delete') {
      _showDeleteTaskConfirm(context, ref);
    }
  }

  void _showRenameTaskDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                await ref.read(taskNotifierProvider.notifier).renameTask(
                  taskId: task.id,
                  newTitle: newTitle,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Task renamed'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTaskConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to delete "${task.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Task deleted'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSetDelayDialog(BuildContext context, WidgetRef ref) {
    int newDelay = task.delayDays;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Task Delay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Current delay: ${task.delayDays} day(s)',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Delay: '),
                  Expanded(
                    child: Slider(
                      value: newDelay.toDouble(),
                      min: 0,
                      max: 30,
                      divisions: 30,
                      label: newDelay == 0 ? 'No delay' : '$newDelay days',
                      activeColor: AppColors.warning,
                      onChanged: (v) =>
                          setDialogState(() => newDelay = v.round()),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$newDelay d',
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(taskNotifierProvider.notifier).updateTaskDelay(
                  projectId: projectId,
                  taskId: task.id,
                  delayDays: newDelay,
                  allTasks: allTasks,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(newDelay == 0
                        ? 'Delay removed'
                        : 'Delay set to $newDelay day(s)'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDependencyDialog(BuildContext context, WidgetRef ref) {
    final candidates = allTasks.where((t) => t.id != task.id).toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Dependency'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: candidates.map((t) => ListTile(
              title: Text(t.title),
              onTap: () {
                Navigator.pop(context);
                ref.read(taskNotifierProvider.notifier).addDependency(
                  taskId: task.id,
                  dependsOnId: t.id,
                  allTasks: allTasks,
                );
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(this.icon, this.label,
      {this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}