// screens/dashboard/analytics_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/score_utils.dart';
import '../../models/simulation_log_model.dart';
import '../../models/task_model.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/task_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  final String projectId;
  const AnalyticsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(projectId));
    final logsAsync = ref.watch(simulationLogsProvider(projectId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('$e'),
        data: (tasks) {
          final result = calculateEfficiencyScore(tasks);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Score Breakdown ────────────────────────────────────────
              Text('Efficiency Breakdown',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _ScoreBreakdownCard(result: result),

              const SizedBox(height: 20),

              // ── Task Status Pie ────────────────────────────────────────
              Text('Task Status Distribution',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _TaskPieChart(tasks: tasks),

              const SizedBox(height: 20),

              // ── Delay by Task Bar ──────────────────────────────────────
              if (tasks.any((t) => t.delayDays > 0)) ...[
                Text('Delay by Task',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _DelayBarChart(tasks: tasks),
                const SizedBox(height: 20),
              ],

              // ── Simulation score history ───────────────────────────────
              Text('Score Over Simulations',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              logsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (logs) => _ScoreLineChart(logs: logs),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Score Breakdown ─────────────────────────────────────────────────────────
class _ScoreBreakdownCard extends StatelessWidget {
  final EfficiencyResult result;
  const _ScoreBreakdownCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Big score
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  result.score.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: _scoreColor(result.score),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('/100',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 18)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Penalty breakdown
            _PenaltyRow(
              label: 'Delay Impact',
              value: result.delayImpact,
              max: 40,
              color: AppColors.warning,
            ),
            const SizedBox(height: 8),
            _PenaltyRow(
              label: 'Blocked Tasks',
              value: result.blockedTaskIndex,
              max: 35,
              color: AppColors.blocked,
            ),
            const SizedBox(height: 8),
            _PenaltyRow(
              label: 'Rework Factor',
              value: result.reworkFactor,
              max: 25,
              color: AppColors.error,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatPill('${result.totalTasks}', 'Total Tasks', AppColors.accent),
                _StatPill('${result.blockedTasks}', 'Blocked', AppColors.blocked),
                _StatPill(
                    '${result.totalTasks - result.blockedTasks}', 'Active', AppColors.success),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 75) return AppColors.success;
    if (s >= 50) return AppColors.warning;
    return AppColors.error;
  }
}

class _PenaltyRow extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _PenaltyRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = value / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            Text(
              '-${value.toStringAsFixed(1)} pts',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatPill(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ── Task Status Pie Chart ────────────────────────────────────────────────────
class _TaskPieChart extends StatelessWidget {
  final List<TaskModel> tasks;
  const _TaskPieChart({required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
              child: Text('No tasks yet',
                  style: TextStyle(color: AppColors.textSecondary))),
        ),
      );
    }

    final pending = tasks.where((t) => t.status == TaskStatus.pending).length;
    final inProgress = tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final blocked = tasks.where((t) => t.status == TaskStatus.blocked).length;
    final completed = tasks.where((t) => t.status == TaskStatus.completed).length;

    final sections = <PieChartSectionData>[];
    void addSection(int count, Color color, String label) {
      if (count == 0) return;
      final pct = count / tasks.length * 100;
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: color,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 55,
        titleStyle: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ));
    }

    addSection(pending, AppColors.textSecondary, 'Pending');
    addSection(inProgress, AppColors.accent, 'In Progress');
    addSection(blocked, AppColors.blocked, 'Blocked');
    addSection(completed, AppColors.success, 'Completed');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              height: 160,
              width: 160,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 32,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Legend('Pending', AppColors.textSecondary, pending),
                _Legend('In Progress', AppColors.accent, inProgress),
                _Legend('Blocked', AppColors.blocked, blocked),
                _Legend('Completed', AppColors.success, completed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  const _Legend(this.label, this.color, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$label ($count)',
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Delay Bar Chart ──────────────────────────────────────────────────────────
class _DelayBarChart extends StatelessWidget {
  final List<TaskModel> tasks;
  const _DelayBarChart({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final delayed = tasks.where((t) => t.delayDays > 0).toList()
      ..sort((a, b) => b.delayDays.compareTo(a.delayDays));
    final display = delayed.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (display.map((t) => t.delayDays).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
              barGroups: display.asMap().entries.map((e) {
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: e.value.delayDays.toDouble(),
                    color: AppColors.warning,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]);
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}d',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx >= display.length) return const SizedBox();
                      final title = display[idx].title;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          title.length > 8 ? '${title.substring(0, 7)}…' : title,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.textSecondary.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Score Line Chart over simulations ───────────────────────────────────────
class _ScoreLineChart extends StatelessWidget {
  final List<SimulationLogModel> logs;
  const _ScoreLineChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('Run simulations to see score history',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
    }

    // Reverse so chronological order (oldest first)
    final ordered = logs.reversed.toList();

    final spots = <FlSpot>[];
    // Add initial score from first log
    if (ordered.isNotEmpty) {
      spots.add(FlSpot(0, ordered.first.scoreBefore));
    }
    for (int i = 0; i < ordered.length; i++) {
      spots.add(FlSpot((i + 1).toDouble(), ordered[i].scoreAfter));
    }

    final minY = (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 5)
        .clamp(0.0, 100.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: 105,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.accent,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.accent,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.accent.withValues(alpha: 0.15),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx == 0) {
                        return const Text('Start',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 9));
                      }
                      return Text('Sim $idx',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 9));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.textSecondary.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}