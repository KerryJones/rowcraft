import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/workout.dart';
import '../../models/workout_segment.dart';
import 'builder_provider.dart';
import 'interval_editor.dart';

class BuilderScreen extends ConsumerStatefulWidget {
  final String? workoutId;

  const BuilderScreen({super.key, this.workoutId});

  @override
  ConsumerState<BuilderScreen> createState() => _BuilderScreenState();
}

class _BuilderScreenState extends ConsumerState<BuilderScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // If editing an existing workout, load it
    if (widget.workoutId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(builderProvider.notifier).loadWorkout(widget.workoutId!);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final builder = ref.watch(builderProvider);

    // Sync text controllers with state
    if (_titleController.text != builder.title && builder.title.isNotEmpty) {
      _titleController.text = builder.title;
    }
    if (_descriptionController.text != builder.description &&
        builder.description.isNotEmpty) {
      _descriptionController.text = builder.description;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutId != null ? 'Edit Workout' : 'New Workout'),
        actions: [
          TextButton(
            onPressed: builder.isSaving ? null : _handleSave,
            child: builder.isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Workout Title',
                hintText: 'e.g. 4x1000m Intervals',
              ),
              onChanged: (value) =>
                  ref.read(builderProvider.notifier).setTitle(value),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional workout description...',
              ),
              maxLines: 3,
              onChanged: (value) =>
                  ref.read(builderProvider.notifier).setDescription(value),
            ),
            const SizedBox(height: 24),

            // Workout type selector
            Text('Workout Type', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<WorkoutType>(
              segments: const [
                ButtonSegment(
                  value: WorkoutType.singleDistance,
                  label: Text('Distance'),
                  icon: Icon(Icons.straighten, size: 18),
                ),
                ButtonSegment(
                  value: WorkoutType.singleTime,
                  label: Text('Time'),
                  icon: Icon(Icons.timer, size: 18),
                ),
                ButtonSegment(
                  value: WorkoutType.intervals,
                  label: Text('Intervals'),
                  icon: Icon(Icons.repeat, size: 18),
                ),
              ],
              selected: {builder.workoutType},
              onSelectionChanged: (types) {
                ref.read(builderProvider.notifier).setType(types.first);
              },
            ),
            const SizedBox(height: 24),

            // Segments header
            Row(
              children: [
                Text('Segments', style: theme.textTheme.headlineSmall),
                const Spacer(),
                Text(
                  '${builder.segments.length} segment${builder.segments.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segment list
            if (builder.segments.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: RowCraftTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: RowCraftTheme.subtleGrey.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_circle_outline,
                        size: 48, color: RowCraftTheme.subtleGrey),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first segment',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: RowCraftTheme.subtleGrey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: builder.segments.length,
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(builderProvider.notifier)
                      .reorderSegment(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  return Dismissible(
                    key: ValueKey('segment_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: RowCraftTheme.errorRose,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(builderProvider.notifier)
                          .removeSegment(index);
                    },
                    child: IntervalEditor(
                      key: ValueKey('editor_$index'),
                      segment: builder.segments[index],
                      index: index,
                      onChanged: (updated) {
                        ref
                            .read(builderProvider.notifier)
                            .updateSegment(index, updated);
                      },
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),

            // Add segment button
            OutlinedButton.icon(
              onPressed: () {
                ref.read(builderProvider.notifier).addSegment(
                      const WorkoutSegment(
                        type: SegmentType.work,
                        durationType: DurationType.distance,
                        durationValue: 500,
                      ),
                    );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Segment'),
            ),

            const SizedBox(height: 16),

            // Quick-add presets
            Text('Quick Add', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetChip(
                  label: '500m Work',
                  onTap: () => _addPreset(SegmentType.work, DurationType.distance, 500),
                ),
                _PresetChip(
                  label: '1000m Work',
                  onTap: () => _addPreset(SegmentType.work, DurationType.distance, 1000),
                ),
                _PresetChip(
                  label: '2000m Work',
                  onTap: () => _addPreset(SegmentType.work, DurationType.distance, 2000),
                ),
                _PresetChip(
                  label: '1:00 Rest',
                  onTap: () => _addPreset(SegmentType.rest, DurationType.time, 60),
                ),
                _PresetChip(
                  label: '2:00 Rest',
                  onTap: () => _addPreset(SegmentType.rest, DurationType.time, 120),
                ),
                _PresetChip(
                  label: '5:00 Warmup',
                  onTap: () => _addPreset(SegmentType.warmup, DurationType.time, 300),
                ),
                _PresetChip(
                  label: '5:00 Cooldown',
                  onTap: () => _addPreset(SegmentType.cooldown, DurationType.time, 300),
                ),
              ],
            ),

            // Error message
            if (builder.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RowCraftTheme.errorRose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  builder.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: RowCraftTheme.errorRose,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _addPreset(SegmentType type, DurationType durationType, double value) {
    ref.read(builderProvider.notifier).addSegment(
          WorkoutSegment(
            type: type,
            durationType: durationType,
            durationValue: value,
          ),
        );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final workout = await ref.read(builderProvider.notifier).save();
    if (workout != null && mounted) {
      context.pop();
    }
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
