// screens/simulation/simulation_screen.dart
//
// Overhauled interactive what-if simulation dashboard.
// Multi-task sliders, real-time score preview, color-coded impact.

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/animated_counter.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/whatif_provider.dart';
import '../../providers/simulation_provider.dart';

class SimulationScreen extends ConsumerStatefulWidget {
  final String projectId;
  const SimulationScreen({super.key, required this.projectId});

  @override
  ConsumerState<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends ConsumerState<SimulationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider(widget.projectId));

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const Center(
            child: Text('Add tasks to run simulations',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return Column(
          children: [
            // Tab bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: AppColors.cardBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(text: '⚡ What-If Engine'),
                  Tab(text: '📜 History'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _WhatIfTab(
                      projectId: widget.projectId, tasks: tasks),
                  _HistoryTab(projectId: widget.projectId),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── What-If Tab ─────────────────────────────────────────────────────────────
class _WhatIfTab extends ConsumerStatefulWidget {
  final String projectId;
  final List<TaskModel> tasks;
  const _WhatIfTab({required this.projectId, required this.tasks});

  @override
  ConsumerState<_WhatIfTab> createState() => _WhatIfTabState();
}

class _WhatIfTabState extends ConsumerState<_WhatIfTab> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Wrap in microtask to avoid "modify provider during build" error
      Future.microtask(() {
        if (mounted) {
          ref.read(whatIfNotifierProvider.notifier).initialize(widget.tasks);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whatIfNotifierProvider);
    final activeTasks =
        widget.tasks.where((t) => !t.isCompleted).toList();

    return Column(
      children: [
        // ── Score comparison bar ──────────────────────────────────
        if (state.result != null)
          FadeIn(
            child: _ScoreComparisonBar(result: state.result!),
          ),

        // ── Task sliders ─────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: activeTasks.length,
            itemBuilder: (_, i) {
              final task = activeTasks[i];
              final currentDelay =
                  state.pendingDelays[task.id] ?? task.delayDays;
              final isBlocked = state.blockedTasks.contains(task.id);

              return FadeInUp(
                delay: Duration(milliseconds: i * 50),
                duration: const Duration(milliseconds: 300),
                child: _WhatIfTaskCard(
                  task: task,
                  delay: currentDelay,
                  isBlocked: isBlocked,
                  onDelayChanged: (d) => ref
                      .read(whatIfNotifierProvider.notifier)
                      .setDelay(task.id, d),
                  onBlockedToggle: () => ref
                      .read(whatIfNotifierProvider.notifier)
                      .toggleBlocked(task.id),
                ),
              );
            },
          ),
        ),

        // ── Action bar ───────────────────────────────────────────
        if (state.isDirty)
          FadeInUp(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(whatIfNotifierProvider.notifier).resetAll(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await ref
                            .read(whatIfNotifierProvider.notifier)
                            .applyChanges(widget.projectId);
                        if (ok && mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Changes applied! ✓'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Apply Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Score Comparison Bar ────────────────────────────────────────────────────
class _ScoreComparisonBar extends StatelessWidget {
  final WhatIfResult result;
  const _ScoreComparisonBar({required this.result});

  @override
  Widget build(BuildContext context) {
    final delta = result.scoreDelta;
    final deltaColor = delta >= 0 ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderColor: deltaColor.withValues(alpha: 0.3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('Current',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 10)),
                AnimatedCounter(
                  value: result.originalScore,
                  decimals: 0,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Column(
              children: [
                Icon(
                  delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: deltaColor,
                  size: 18,
                ),
                Text(
                  '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)}',
                  style: TextStyle(
                      color: deltaColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Column(
              children: [
                const Text('After',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 10)),
                AnimatedCounter(
                  value: result.newScore,
                  decimals: 0,
                  style: TextStyle(
                      color: deltaColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${result.affectedTaskCount} affected',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── What-If Task Card ───────────────────────────────────────────────────────
class _WhatIfTaskCard extends StatelessWidget {
  final TaskModel task;
  final int delay;
  final bool isBlocked;
  final ValueChanged<int> onDelayChanged;
  final VoidCallback onBlockedToggle;

  const _WhatIfTaskCard({
    required this.task,
    required this.delay,
    required this.isBlocked,
    required this.onDelayChanged,
    required this.onBlockedToggle,
  });

  Color get _delayColor {
    if (delay == 0) return AppColors.success;
    if (delay <= 3) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isBlocked
            ? AppColors.blocked.withValues(alpha: 0.08)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocked
              ? AppColors.blocked.withValues(alpha: 0.3)
              : delay > 0
                  ? _delayColor.withValues(alpha: 0.3)
                  : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? AppColors.blocked
                        : _delayColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 13,
                          )),
                ),
                // Blocked toggle
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: isBlocked,
                    onChanged: (_) => onBlockedToggle(),
                    activeTrackColor: AppColors.blocked.withValues(alpha: 0.4),
                    inactiveThumbColor: AppColors.textSecondary,
                  ),
                ),
                const Text('Block',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Delay: ',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: _delayColor,
                      inactiveTrackColor:
                          _delayColor.withValues(alpha: 0.15),
                      thumbColor: _delayColor,
                      overlayColor: _delayColor.withValues(alpha: 0.2),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: delay.toDouble(),
                      min: 0,
                      max: 30,
                      divisions: 30,
                      label: delay == 0 ? 'No delay' : '$delay days',
                      onChanged: (v) => onDelayChanged(v.round()),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _delayColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${delay}d',
                    style: TextStyle(
                        color: _delayColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Tab ─────────────────────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  final String projectId;
  const _HistoryTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(simulationLogsProvider(projectId));

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(
            child: Text('No simulations run yet.',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (_, i) {
            final log = logs[i];
            final delta = log.scoreAfter - log.scoreBefore;
            return FadeInUp(
              delay: Duration(milliseconds: i * 50),
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    delta >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: delta >= 0 ? AppColors.success : AppColors.error,
                  ),
                  title: Text(log.triggeredByTaskTitle,
                      style: Theme.of(context).textTheme.bodyMedium),
                  subtitle: Text(
                      '+${log.delayApplied}d · ${log.affectedTaskIds.length} affected'),
                  trailing: Text(
                    '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)}',
                    style: TextStyle(
                        color:
                            delta >= 0 ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}