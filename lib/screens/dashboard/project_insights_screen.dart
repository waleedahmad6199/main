// screens/dashboard/project_insights_screen.dart
//
// Insight-driven dashboard that surfaces actionable intelligence.
// Replaces passive charts with computed, color-coded insight cards.

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/animated_counter.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/insight_model.dart';
import '../../models/task_model.dart';
import '../../providers/insight_provider.dart';
import '../../providers/task_provider.dart';
import '../../core/utils/score_utils.dart';
import '../../services/prediction_engine.dart';

class ProjectInsightsScreen extends ConsumerWidget {
  final String projectId;
  const ProjectInsightsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(projectId));
    final insights = ref.watch(insightProvider(projectId));

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(
            child: FadeIn(
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_rounded,
                      size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text('Add tasks to see insights',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }

        final prediction = PredictionEngine.predict(tasks);
        final scoreResult = calculateEfficiencyScore(tasks);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            // ── Prediction Hero Card ───────────────────────────────────
            FadeInDown(
              child: _PredictionCard(prediction: prediction),
            ),
            const SizedBox(height: 16),

            // ── Score Summary ──────────────────────────────────────────
            FadeInLeft(
              delay: const Duration(milliseconds: 150),
              child: _ScoreSummaryCard(
                  score: scoreResult.score, tasks: tasks),
            ),
            const SizedBox(height: 16),

            // ── Insights ───────────────────────────────────────────────
            if (insights.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('AI Insights',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ...insights.asMap().entries.map((entry) {
                final i = entry.key;
                final insight = entry.value;
                return FadeInUp(
                  delay: Duration(milliseconds: 200 + i * 80),
                  child: _InsightCard(insight: insight),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

// ── Prediction Hero Card ───────────────────────────────────────────────────
class _PredictionCard extends StatelessWidget {
  final PredictionResult prediction;
  const _PredictionCard({required this.prediction});

  Color get _statusColor {
    switch (prediction.status) {
      case 'critical':
        return AppColors.error;
      case 'at_risk':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  IconData get _statusIcon {
    switch (prediction.status) {
      case 'critical':
        return Icons.local_fire_department_rounded;
      case 'at_risk':
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  String get _statusLabel {
    switch (prediction.status) {
      case 'critical':
        return 'CRITICAL';
      case 'at_risk':
        return 'AT RISK';
      default:
        return 'ON TRACK';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: _statusColor.withValues(alpha: 0.3),
      tint: _statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_statusLabel,
                              style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                        const Spacer(),
                        Text(
                          '${prediction.estimatedDaysRemaining}d remaining',
                          style: TextStyle(
                              color: _statusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      prediction.summary,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (prediction.optimizations.isNotEmpty) ...[
            const Divider(height: 20),
            ...prediction.optimizations.take(2).map(
                  (opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 14, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(opt,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

// ── Score Summary Card ─────────────────────────────────────────────────────
class _ScoreSummaryCard extends StatelessWidget {
  final double score;
  final List<TaskModel> tasks;
  const _ScoreSummaryCard({required this.score, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((t) => t.isCompleted).length;
    final blocked = tasks.where((t) => t.isBlocked).length;
    final delayed = tasks.where((t) => t.delayDays > 0).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Score gauge
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: score / 100),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 6,
                      backgroundColor:
                          AppColors.textSecondary.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(
                          _scoreColor(score)),
                    ),
                  ),
                  AnimatedCounter(
                    value: score,
                    style: TextStyle(
                      color: _scoreColor(score),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    decimals: 0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniStat(
                      '✅ $completed completed',
                      AppColors.success),
                  const SizedBox(height: 4),
                  _MiniStat(
                      '🚫 $blocked blocked',
                      AppColors.blocked),
                  const SizedBox(height: 4),
                  _MiniStat(
                      '⏱️ $delayed delayed',
                      AppColors.warning),
                ],
              ),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniStat(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w500));
  }
}

// ── Insight Card ───────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final ProjectInsight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: insight.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(insight.icon, color: insight.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${insight.emoji} ${insight.title}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(insight.description,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4)),
                  if (insight.actionLabel != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: insight.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(insight.actionLabel!,
                          style: TextStyle(
                              color: insight.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
