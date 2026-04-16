// screens/onboarding/ai_onboarding_screen.dart
//
// Full-screen AI-powered onboarding experience.
// Tasks, risks, and milestones appear with staggered animations.

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pulse_dot.dart';
import '../../models/ai_project_plan.dart';
import '../../providers/ai_onboarding_provider.dart';
import '../project/project_detail_screen.dart';

class AiOnboardingScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectDescription;

  const AiOnboardingScreen({
    super.key,
    required this.projectId,
    required this.projectDescription,
  });

  @override
  ConsumerState<AiOnboardingScreen> createState() =>
      _AiOnboardingScreenState();
}

class _AiOnboardingScreenState extends ConsumerState<AiOnboardingScreen> {
  @override
  void initState() {
    super.initState();
    // Start generation immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(aiOnboardingNotifierProvider.notifier)
          .generatePlan(widget.projectDescription);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiOnboardingNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: state.isLoading
            ? _LoadingView(message: state.loadingMessage)
            : state.errorMessage != null
                ? _ErrorView(
                    error: state.errorMessage!,
                    onRetry: () => ref
                        .read(aiOnboardingNotifierProvider.notifier)
                        .generatePlan(widget.projectDescription),
                  )
                : state.plan != null
                    ? _PlanView(
                        plan: state.plan!,
                        isSaving: state.isSaving,
                        onSave: _savePlan,
                        onSkip: _goToProject,
                      )
                    : const SizedBox(),
      ),
    );
  }

  Future<void> _savePlan() async {
    final success =
        await ref.read(aiOnboardingNotifierProvider.notifier).savePlanToFirestore(
              projectId: widget.projectId,
              stageId: 'stage_todo',
            );
    if (success && mounted) {
      _goToProject();
    }
  }

  void _goToProject() {
    ref.read(aiOnboardingNotifierProvider.notifier).reset();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: widget.projectId),
      ),
    );
  }
}

// ── Loading View ────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeInDown(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.3),
                    AppColors.primaryLight.withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 48, color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 32),
          FadeIn(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulseDot(color: AppColors.accent),
                const SizedBox(width: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.accent,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FadeIn(
            delay: const Duration(milliseconds: 500),
            child: SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error View ──────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plan View (animated reveal) ─────────────────────────────────────────────
class _PlanView extends StatelessWidget {
  final AiProjectPlan plan;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onSkip;

  const _PlanView({
    required this.plan,
    required this.isSaving,
    required this.onSave,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        FadeInDown(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: AppColors.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Project Plan',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        'Timeline: ${plan.estimatedTimeline} · ${plan.tasks.length} tasks · ${plan.risks.length} risks',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // ── Milestones Timeline ──────────────────
              if (plan.milestones.isNotEmpty) ...[
                FadeInLeft(
                  delay: const Duration(milliseconds: 200),
                  child: Text('🎯 Milestones',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                ...plan.milestones.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  return FadeInLeft(
                    delay: Duration(milliseconds: 300 + i * 100),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.accent,
                                    AppColors.primaryLight,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  m.targetWeek,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text(
                                    '${m.taskTitles.length} tasks',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],

              // ── Tasks ───────────────────────────────
              FadeInLeft(
                delay: const Duration(milliseconds: 500),
                child: Text('📋 Generated Tasks',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              ...plan.tasks.asMap().entries.map((entry) {
                final i = entry.key;
                final task = entry.value;
                return FadeInUp(
                  delay: Duration(milliseconds: 600 + i * 80),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.accent,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule,
                                        size: 12,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(task.duration,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                    if (task.dependsOn.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.link,
                                          size: 12,
                                          color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text('${task.dependsOn.length} dep',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // ── Risks ───────────────────────────────
              if (plan.risks.isNotEmpty) ...[
                FadeInLeft(
                  delay: Duration(
                      milliseconds: 700 + plan.tasks.length * 80),
                  child: Text('⚠️ Identified Risks',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                ...plan.risks.asMap().entries.map((entry) {
                  final i = entry.key;
                  final risk = entry.value;
                  return FadeInRight(
                    delay: Duration(
                        milliseconds: 800 + plan.tasks.length * 80 + i * 100),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: risk.isHigh
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : risk.isMedium
                                        ? AppColors.warning
                                            .withValues(alpha: 0.15)
                                        : AppColors.success
                                            .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                risk.isHigh
                                    ? Icons.local_fire_department
                                    : risk.isMedium
                                        ? Icons.warning_amber
                                        : Icons.info_outline,
                                size: 18,
                                color: risk.isHigh
                                    ? AppColors.error
                                    : risk.isMedium
                                        ? AppColors.warning
                                        : AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(risk.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(risk.mitigation,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),

        // ── Bottom action bar ─────────────────────────────────────
        FadeInUp(
          delay: Duration(milliseconds: 900 + plan.tasks.length * 80),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context)
                      .scaffoldBackgroundColor
                      .withValues(alpha: 0.0),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onSkip,
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : onSave,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rocket_launch),
                    label: Text(isSaving
                        ? 'Saving...'
                        : 'Launch Project Dashboard →'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
