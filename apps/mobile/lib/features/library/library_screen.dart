import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/workout.dart';
import '../ble/ble_provider.dart';
import '../ble/pm5_service.dart';
import '../plans/plans_catalog.dart';
import 'library_provider.dart';

enum _LibraryTab { workouts, plans }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  WorkoutType? _selectedType;
  String? _selectedTag;
  _LibraryTab _tab = _LibraryTab.workouts;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RowCraft'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final bleState = ref.watch(bleProvider);
              final isConnected = bleState.pm5ConnectionState ==
                  PM5ConnectionState.connected;
              return IconButton(
                icon: Icon(
                  Icons.bluetooth,
                  color: isConnected
                      ? RowCraftTheme.primaryBlue
                      : RowCraftTheme.subtleGrey,
                ),
                onPressed: () => context.push('/devices'),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented control
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_LibraryTab>(
                segments: const [
                  ButtonSegment(
                    value: _LibraryTab.workouts,
                    label: Text('Workouts'),
                    icon: Icon(Icons.fitness_center, size: 18),
                  ),
                  ButtonSegment(
                    value: _LibraryTab.plans,
                    label: Text('Plans'),
                    icon: Icon(Icons.calendar_month, size: 18),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (selection) {
                  setState(() => _tab = selection.first);
                },
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: _tab == _LibraryTab.workouts
                ? _WorkoutsTab(
                    searchController: _searchController,
                    selectedType: _selectedType,
                    selectedTag: _selectedTag,
                    onTypeChanged: (type) =>
                        setState(() => _selectedType = type),
                    onSearchChanged: () => setState(() {}),
                  )
                : const PlansCatalog(),
          ),
        ],
      ),
      floatingActionButton: _tab == _LibraryTab.workouts
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/builder'),
              icon: const Icon(Icons.add),
              label: const Text('New Workout'),
            )
          : null,
    );
  }
}

class _WorkoutsTab extends ConsumerWidget {
  final TextEditingController searchController;
  final WorkoutType? selectedType;
  final String? selectedTag;
  final ValueChanged<WorkoutType?> onTypeChanged;
  final VoidCallback onSearchChanged;

  const _WorkoutsTab({
    required this.searchController,
    required this.selectedType,
    required this.selectedTag,
    required this.onTypeChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workoutsAsync = ref.watch(filteredWorkoutsProvider((
      search: searchController.text,
      type: selectedType,
      tag: selectedTag,
    )));

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search workouts...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged();
                      },
                    )
                  : null,
            ),
            onChanged: (_) => onSearchChanged(),
          ),
        ),

        // Filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildTypeChip(null, 'All'),
              _buildTypeChip(WorkoutType.singleDistance, 'Distance'),
              _buildTypeChip(WorkoutType.singleTime, 'Time'),
              _buildTypeChip(WorkoutType.intervals, 'Intervals'),
              _buildTypeChip(WorkoutType.variableIntervals, 'Variable'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Workout list
        Expanded(
          child: workoutsAsync.when(
            data: (workouts) {
              if (workouts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rowing,
                        size: 64,
                        color: RowCraftTheme.subtleGrey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No workouts found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: RowCraftTheme.subtleGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first workout to get started',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(workoutLibraryProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: workouts.length,
                  itemBuilder: (context, index) {
                    return _WorkoutCard(workout: workouts[index]);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: RowCraftTheme.errorRose,
                  ),
                  const SizedBox(height: 16),
                  Text('Failed to load workouts',
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(workoutLibraryProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(WorkoutType? type, String label) {
    final isSelected = selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          onTypeChanged(isSelected ? null : type);
        },
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Workout workout;

  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => context.push('/workout/${workout.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workout.title,
                      style: theme.textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _WorkoutTypeBadge(type: workout.workoutType),
                ],
              ),
              if (workout.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  workout.description,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  // Segment count
                  Icon(Icons.format_list_numbered,
                      size: 16, color: RowCraftTheme.subtleGrey),
                  const SizedBox(width: 4),
                  Text(
                    '${workout.segments.length} segments',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  // Fork count
                  if (workout.forkCount > 0) ...[
                    Icon(Icons.fork_right,
                        size: 16, color: RowCraftTheme.subtleGrey),
                    const SizedBox(width: 4),
                    Text(
                      '${workout.forkCount}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () =>
                        context.push('/builder/${workout.id}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              // Tags
              if (workout.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: workout.tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutTypeBadge extends StatelessWidget {
  final WorkoutType type;

  const _WorkoutTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      WorkoutType.singleDistance => ('Distance', RowCraftTheme.segmentWork),
      WorkoutType.singleTime => ('Time', RowCraftTheme.segmentWarmup),
      WorkoutType.intervals => ('Intervals', RowCraftTheme.warningAmber),
      WorkoutType.variableIntervals => ('Variable', RowCraftTheme.segmentCooldown),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
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
