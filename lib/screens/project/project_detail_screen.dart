// screens/project/project_detail_screen.dart
//
// Main project detail screen with tabs: Tasks, Insights, Graph, Simulate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/project_provider.dart';
import '../dashboard/project_insights_screen.dart';
import '../graph/graph_view_screen.dart';
import '../simulation/simulation_screen.dart';
import '../task/task_list_screen.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  void _showRenameDialog(BuildContext context, WidgetRef ref, String projectId, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Project'),
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
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                ref
                    .read(projectNotifierProvider.notifier)
                    .updateProject(projectId: projectId, title: newTitle);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, String projectId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text('Are you sure you want to delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(projectNotifierProvider.notifier).deleteProject(projectId);
              Navigator.pop(context);
              Navigator.pop(context); // Pop the detail screen as well
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectStreamProvider(projectId));

    return projectAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (project) {
        if (project == null) {
          return const Scaffold(body: Center(child: Text('Not found')));
        }
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(project.title),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') {
                      _showRenameDialog(context, ref, project.id, project.title);
                    } else if (value == 'delete') {
                      _showDeleteConfirm(context, ref, project.id, project.title);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 12),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: AppColors.error),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(Icons.list_alt), text: 'Tasks'),
                  Tab(icon: Icon(Icons.insights), text: 'Insights'),
                  Tab(icon: Icon(Icons.account_tree), text: 'Graph'),
                  Tab(icon: Icon(Icons.science), text: 'Simulate'),
                ],
                labelColor: AppColors.accent,
                indicatorColor: AppColors.accent,
                tabAlignment: TabAlignment.start,
              ),
            ),
            body: TabBarView(
              children: [
                TaskListScreen(projectId: projectId, project: project),
                ProjectInsightsScreen(projectId: projectId),
                GraphViewScreen(projectId: projectId),
                SimulationScreen(projectId: projectId),
              ],
            ),
          ),
        );
      },
    );
  }
}
