// screens/dashboard/dashboard_screen.dart
//
// Redesigned dashboard with staggered animations, shimmer loading,
// and gradient project cards.

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/animated_counter.dart';
import '../../core/widgets/pulse_dot.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/theme_provider.dart';
import '../project/create_project_screen.dart';
import '../project/project_detail_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final isDark = ref.watch(themeNotifierProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: FadeIn(
          child: Row(
            children: [
              Image.asset('assets/icons/app_icon.png', width: 32, height: 32),
              const SizedBox(width: 10),
              const Text('FlowIQ'),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(themeNotifierProvider.notifier).toggle(),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.person, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const ShimmerLoading(itemCount: 4, height: 110),
        error: (e, _) => Center(child: Text('$e')),
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
              child: FadeInUp(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.rocket_launch,
                          size: 56, color: AppColors.accent),
                    ),
                    const SizedBox(height: 20),
                    Text('No projects yet',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Create your first project and let AI plan it for you!',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CreateProjectScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/icons/app_icon.png', width: 20, height: 20),
                          const SizedBox(width: 8),
                          const Text('Create with AI ✨'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome header ──────────────────────────────────────
              FadeInDown(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${userAsync.value?.name.split(' ').first ?? "User"} 👋',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontSize: 20),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const PulseDot(color: AppColors.success, size: 6),
                                const SizedBox(width: 6),
                                Text(
                                  '${projects.length} active project${projects.length == 1 ? "" : "s"}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Projects list ──────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: projects.length,
                  itemBuilder: (_, i) {
                    final p = projects[i];
                    return FadeInUp(
                      delay: Duration(milliseconds: 100 + i * 80),
                      child: _ProjectCard(
                        projectId: p.id,
                        title: p.title,
                        description: p.description,
                        score: p.efficiencyScore,
                        stageCount: p.stages.length,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProjectDetailScreen(projectId: p.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FadeInUp(
        delay: const Duration(milliseconds: 500),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
          ),
          backgroundColor: AppColors.accent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Project',
              style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

// ── Project Card ────────────────────────────────────────────────────────────
class _ProjectCard extends ConsumerWidget {
  final String projectId;
  final String title;
  final String description;
  final double score;
  final int stageCount;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.projectId,
    required this.title,
    required this.description,
    required this.score,
    required this.stageCount,
    required this.onTap,
  });

  Color get _scoreColor {
    if (score >= 75) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename Project'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete Project',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirm(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: title);
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

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: () => _showOptions(context, ref),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _scoreColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                // Score ring
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: score / 100),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 4,
                          backgroundColor:
                              _scoreColor.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(_scoreColor),
                        ),
                      ),
                      AnimatedCounter(
                        value: score,
                        decimals: 0,
                        style: TextStyle(
                          color: _scoreColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.textSecondary, size: 22),
                  onPressed: () => _showOptions(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
