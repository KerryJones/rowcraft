import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/workout.dart';
import '../../widgets/wod_card.dart';
import '../../widgets/workout_graph.dart';
import '../../widgets/workout_type_badge.dart';
import '../plans/plans_provider.dart';
import 'library_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  WorkoutType? _selectedType;
  int _wodShuffleOffset = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workoutsAsync = ref.watch(filteredWorkoutsProvider((
      search: _searchController.text,
      type: _selectedType,
      tag: null,
    )));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search workouts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
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
                        const Icon(
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

                // WOD: only show when no filters active
                final hasFilters = _searchController.text.isNotEmpty ||
                    _selectedType != null;
                final allWorkouts =
                    ref.watch(workoutLibraryProvider).valueOrNull ?? [];

                // Build WOD pool: exclude tests and plan workouts
                const wodExcludeTags = {'ftp', 'ramp', 'test'};
                final plans =
                    ref.watch(trainingPlansProvider).valueOrNull ?? [];
                final planWorkoutIds = <String>{
                  for (final plan in plans)
                    for (final week in plan.weeks)
                      for (final session in week.sessions)
                        session.workoutId,
                };
                final wodPool = allWorkouts
                    .where((w) =>
                        !w.tags.any(wodExcludeTags.contains) &&
                        !planWorkoutIds.contains(w.id))
                    .toList();

                Workout? wodWorkout;
                if (!hasFilters && wodPool.isNotEmpty) {
                  final wodIdx = getWodIndex(wodPool.length,
                      shuffleOffset: _wodShuffleOffset);
                  wodWorkout = wodPool[wodIdx];
                }

                // Exclude WOD from filtered list (keep if only 1 workout)
                final wod = wodWorkout;
                final displayWorkouts = wod != null && workouts.length > 1
                    ? workouts
                        .where((w) => w.id != wod.id)
                        .toList()
                    : workouts;

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(workoutLibraryProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: displayWorkouts.length + (wod != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // WOD card at position 0
                      if (wod != null && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: WodCard(
                            workout: wod,
                            canShuffle: wodPool.length > 1,
                            onTap: () =>
                                context.push('/workout/${wod.id}'),
                            onShuffle: () {
                              setState(() => _wodShuffleOffset++);
                            },
                          ),
                        );
                      }
                      final workoutIndex =
                          wod != null ? index - 1 : index;
                      return _WorkoutCard(
                          workout: displayWorkouts[workoutIndex]);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
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
      ),
    );
  }

  Widget _buildTypeChip(WorkoutType? type, String label) {
    final isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedType = isSelected ? null : type);
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
                  WorkoutTypeBadge(type: workout.workoutType),
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
              const SizedBox(height: 10),

              // Segment graph
              WorkoutGraph(segments: workout.segments, height: 56),

              const SizedBox(height: 10),
              Row(
                children: [
                  // Segment count
                  const Icon(Icons.segment,
                      size: 14, color: RowCraftTheme.subtleGrey),
                  const SizedBox(width: 4),
                  Text(
                    '${workout.segments.length} segments',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  // Fork count
                  if (workout.forkCount > 0) ...[
                    const Icon(Icons.fork_right,
                        size: 14, color: RowCraftTheme.subtleGrey),
                    const SizedBox(width: 4),
                    Text(
                      '${workout.forkCount}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
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

