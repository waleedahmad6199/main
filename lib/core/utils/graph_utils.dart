// core/utils/graph_utils.dart
//
// Pure Dart graph algorithms. No Flutter dependencies.
// Used by the SimulationEngine to propagate delays through the task DAG.

import '../../models/task_model.dart';

/// Builds an adjacency list: taskId → [taskIds that depend ON it]
/// i.e. reverse of dependencyIds (which lists what a task depends on).
/// If task B depends on task A → edge A→B (A must finish before B).
Map<String, List<String>> buildDependentMap(List<TaskModel> tasks) {
  final Map<String, List<String>> map = {
    for (final t in tasks) t.id: <String>[],
  };
  for (final task in tasks) {
    for (final depId in task.dependencyIds) {
      map[depId] ??= [];
      map[depId]!.add(task.id);
    }
  }
  return map;
}

/// DFS-based reachability from [startId].
/// Returns all task IDs reachable from [startId] in topological order
/// (i.e. all tasks that are directly or transitively blocked by startId).
List<String> reachableTasks({
  required String startId,
  required Map<String, List<String>> dependentMap,
}) {
  final visited = <String>{};
  final result = <String>[];

  void dfs(String nodeId) {
    if (visited.contains(nodeId)) return;
    visited.add(nodeId);
    for (final child in (dependentMap[nodeId] ?? [])) {
      dfs(child);
    }
    result.add(nodeId); // post-order → reverse topological
  }

  dfs(startId);
  // Remove the start node itself (it is the trigger, not an affected task)
  result.remove(startId);
  return result.reversed.toList(); // topological order
}

/// Full topological sort of all tasks using Kahn's algorithm.
/// Returns ordered list of task IDs, or throws if a cycle is detected.
List<String> topologicalSort(List<TaskModel> tasks) {
  final inDegree = <String, int>{for (final t in tasks) t.id: 0};
  final adjList = <String, List<String>>{for (final t in tasks) t.id: []};

  for (final task in tasks) {
    for (final depId in task.dependencyIds) {
      adjList[depId] ??= [];
      adjList[depId]!.add(task.id);
      inDegree[task.id] = (inDegree[task.id] ?? 0) + 1;
    }
  }

  final queue = <String>[
    ...inDegree.entries.where((e) => e.value == 0).map((e) => e.key),
  ];
  final sorted = <String>[];

  while (queue.isNotEmpty) {
    final node = queue.removeAt(0);
    sorted.add(node);
    for (final neighbor in (adjList[node] ?? [])) {
      inDegree[neighbor] = (inDegree[neighbor] ?? 1) - 1;
      if (inDegree[neighbor] == 0) queue.add(neighbor);
    }
  }

  if (sorted.length != tasks.length) {
    throw StateError('Cycle detected in task dependency graph.');
  }
  return sorted;
}

/// Detects whether adding an edge from [fromId] to [toId] would create a cycle.
bool wouldCreateCycle({
  required String fromId,
  required String toId,
  required List<TaskModel> tasks,
}) {
  // Build current adjacency (dependency direction: dep→task)
  final adj = <String, List<String>>{for (final t in tasks) t.id: []};
  for (final task in tasks) {
    for (final depId in task.dependencyIds) {
      adj[depId] ??= [];
      adj[depId]!.add(task.id);
    }
  }
  // Add the proposed edge
  adj[fromId] ??= [];
  adj[fromId]!.add(toId);

  // DFS from toId: if we can reach fromId, adding this edge creates a cycle
  final visited = <String>{};
  bool canReach(String current) {
    if (current == fromId) return true;
    if (visited.contains(current)) return false;
    visited.add(current);
    return (adj[current] ?? []).any(canReach);
  }

  return canReach(toId);
}