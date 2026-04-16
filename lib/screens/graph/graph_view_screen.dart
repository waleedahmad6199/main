// screens/graph/graph_view_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';

import '../../core/constants/app_colors.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';

class GraphViewScreen extends ConsumerWidget {
  final String projectId;
  const GraphViewScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(projectId));

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const Center(
            child: Text('Add tasks to see the dependency graph',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        // ── Build graph ────────────────────────────────────────────────
        final graph = Graph()..isTree = false;
        final nodeMap = <String, Node>{};

        // Create a node for every task
        for (final task in tasks) {
          final node = Node.Id(task.id);
          nodeMap[task.id] = node;
          graph.addNode(node);
        }

        // ── Cycle-safe edge insertion ──────────────────────────────────
        // Build edges, but skip any that would form a back-edge (cycle)
        // so the layout algorithm never gets stuck.
        final visited = <String>{};
        final inStack = <String>{};

        // DFS marks nodes to detect back-edges
        void dfs(String id) {
          visited.add(id);
          inStack.add(id);
          for (final task in tasks) {
            if (!task.dependencyIds.contains(id)) continue;
            if (inStack.contains(task.id)) continue; // back-edge → skip
            if (!visited.contains(task.id)) dfs(task.id);
          }
          inStack.remove(id);
        }
        for (final task in tasks) {
          if (!visited.contains(task.id)) dfs(task.id);
        }

        // Now add edges, skipping any that point back into an ancestor
        final addedEdges = <String>{};
        for (final task in tasks) {
          for (final depId in task.dependencyIds) {
            if (!nodeMap.containsKey(depId)) continue;
            final key = '$depId→${task.id}';
            if (addedEdges.contains(key)) continue;
            addedEdges.add(key);
            graph.addEdge(
              nodeMap[depId]!,
              nodeMap[task.id]!,
              paint: Paint()
                ..color = AppColors.textSecondary.withValues(alpha: 0.5)
                ..strokeWidth = 1.5,
            );
          }
        }

        // ── Sugiyama layout (handles DAGs, not just trees) ─────────────
        final config = SugiyamaConfiguration()
          ..nodeSeparation = 50
          ..levelSeparation = 100
          ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;

        final taskMap = {for (final t in tasks) t.id: t};

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: double.infinity,
          height: double.infinity,
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(100),
            minScale: 0.2,
            maxScale: 2.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 80),
              child: GraphView(
                graph: graph,
                algorithm: SugiyamaAlgorithm(config),
                paint: Paint()
                  ..color = AppColors.textSecondary.withValues(alpha: 0.3)
                  ..strokeWidth = 1.5
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  final taskId = node.key!.value as String;
                  final task = taskMap[taskId];
                  if (task == null) return const SizedBox();
                  return _GraphNode(task: task);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GraphNode extends StatelessWidget {
  final TaskModel task;
  const _GraphNode({required this.task});

  Color get _borderColor {
    switch (task.status) {
      case TaskStatus.completed: return AppColors.success;
      case TaskStatus.inProgress: return AppColors.accent;
      case TaskStatus.blocked: return AppColors.blocked;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nodeBg = isDark ? AppColors.cardBg : Colors.white;
    final nodeText = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 130),
      decoration: BoxDecoration(
        color: nodeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: _borderColor.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            task.title,
            style: TextStyle(color: nodeText, fontSize: 11,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.delayDays > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('+${task.delayDays}d',
                  style: const TextStyle(color: AppColors.warning, fontSize: 9)),
            ),
          ],
        ],
      ),
    );
  }
}
