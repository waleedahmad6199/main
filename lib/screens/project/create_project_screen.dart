// screens/project/create_project_screen.dart
//
// Project creation screen with AI-powered onboarding toggle.
// When AI planning is enabled, routes to AiOnboardingScreen after creation.

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/project_provider.dart';
import '../onboarding/ai_onboarding_screen.dart';
import '../project/project_detail_screen.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _useAiPlanning = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final project =
        await ref.read(projectNotifierProvider.notifier).createProject(
              title: _titleCtrl.text.trim(),
              description: _descCtrl.text.trim(),
            );
    if (project != null && mounted) {
      if (_useAiPlanning) {
        // Route to AI onboarding for instant project planning
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AiOnboardingScreen(
              projectId: project.id,
              projectDescription:
                  '${_titleCtrl.text.trim()}: ${_descCtrl.text.trim()}',
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(projectId: project.id),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectNotifierProvider);
    final isLoading = state is AsyncLoading;

    ref.listen(projectNotifierProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('New Project')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              FadeInDown(
                child: TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Project Title',
                    prefixIcon:
                        Icon(Icons.folder_outlined, color: AppColors.accent),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Description
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'What are you building? (Be descriptive for better AI planning)',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined,
                        color: AppColors.accent),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Description is required'
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // ── AI Planning Toggle ───────────────────────────────────
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: _useAiPlanning
                        ? LinearGradient(
                            colors: [
                              AppColors.accent.withValues(alpha: 0.12),
                              AppColors.primaryLight.withValues(alpha: 0.08),
                            ],
                          )
                        : null,
                    border: Border.all(
                      color: _useAiPlanning
                          ? AppColors.accent.withValues(alpha: 0.4)
                          : AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () =>
                        setState(() => _useAiPlanning = !_useAiPlanning),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _useAiPlanning
                                ? AppColors.accent.withValues(alpha: 0.15)
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: _useAiPlanning
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🧠 AI Project Planning',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: _useAiPlanning
                                      ? AppColors.accent
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Let AI generate tasks, risks & milestones from your description',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _useAiPlanning,
                          onChanged: (v) =>
                              setState(() => _useAiPlanning = v),
                          activeTrackColor: AppColors.accent.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Default stages preview
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Default Stages',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _stageChip('To Do', const Color(0xFF607D8B)),
                        _stageChip('In Progress', const Color(0xFF1976D2)),
                        _stageChip('Review', const Color(0xFFF57C00)),
                        _stageChip('Done', const Color(0xFF388E3C)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Stages can be customized after creation.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _submit,
                  icon: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_useAiPlanning
                          ? Icons.auto_awesome
                          : Icons.add_circle_outline),
                  label: Text(_useAiPlanning
                      ? 'Create & Plan with AI ✨'
                      : 'Create Project'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _useAiPlanning ? AppColors.accent : null,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
