// screens/task/task_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../core/constants/app_colors.dart';
import '../../models/stage_model.dart';
import '../../providers/task_provider.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final String projectId;
  final List<StageModel> stages;
  const TaskFormScreen({super.key, required this.projectId, required this.stages});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _daysCtrl = TextEditingController(text: '3');
  String? _selectedStageId;

  @override
  void initState() {
    super.initState();
    _selectedStageId = widget.stages.isNotEmpty ? widget.stages.first.id : null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(taskNotifierProvider.notifier).addTask(
      projectId: widget.projectId,
      stageId: _selectedStageId!,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      estimatedDays: int.tryParse(_daysCtrl.text) ?? 1,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskNotifierProvider);
    final isLoading = state is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Task Title'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated Days',
                  suffixText: 'days',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedStageId,
                decoration: const InputDecoration(labelText: 'Stage'),
                items: widget.stages.map((s) {
                  return DropdownMenuItem(value: s.id, child: Text(s.name));
                }).toList(),
                onChanged: (v) => setState(() => _selectedStageId = v),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Add Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}