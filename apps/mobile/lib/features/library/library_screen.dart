import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/workout.dart';
import '../../utils/pace_utils.dart' show kDefaultFtpWatts;
import '../../utils/workout_utils.dart';
import '../../widgets/ble_status_button.dart';
import '../../widgets/wod_card.dart';
import '../../widgets/workout_graph.dart';
import '../../widgets/workout_type_badge.dart';
import '../plans/plans_provider.dart';
import '../../services/workout_repository.dart';
import 'library_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  WorkoutType? _selectedType;
  DurationFilter? _selectedDuration;
  int? _selectedZone;
  LibrarySortOrder _sortOrder = LibrarySortOrder.newest;
  int _wodShuffleOffset = 0;

  bool get _hasFilters =>
      _searchController.text.isNotEmpty ||
      _selectedType != null ||
      _selectedDuration != null ||
      _selectedZone != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterSheet({
    required String title,
    required List<({String label, bool selected, VoidCallback onTap})> options,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...options.map((opt) => ListTile(
                  title: Text(opt.label),
                  trailing: opt.selected
                      ? const Icon(Icons.check, color: RowCraftTheme.primaryBlue)
                      : null,
                  onTap: () {
                    opt.onTap();
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDurationFilter() {
    _showFilterSheet(
      title: 'Duration',
      options: [
        (
          label: 'Any',
          selected: _selectedDuration == null,
          onTap: () => setState(() => _selectedDuration = null),
        ),
        (
          label: 'Under 30 min',
          selected: _selectedDuration == DurationFilter.under30,
          onTap: () => setState(() => _selectedDuration = DurationFilter.under30),
        ),
        (
          label: '30–60 min',
          selected: _selectedDuration == DurationFilter.from30to60,
          onTap: () => setState(() => _selectedDuration = DurationFilter.from30to60),
        ),
        (
          label: '60+ min',
          selected: _selectedDuration == DurationFilter.over60,
          onTap: () => setState(() => _selectedDuration = DurationFilter.over60),
        ),
      ],
    );
  }

  void _showZoneFilter() {
    _showFilterSheet(
      title: 'Zone',
      options: [
        (
          label: 'Any',
          selected: _selectedZone == null,
          onTap: () => setState(() => _selectedZone = null),
        ),
        for (final (z, name) in [
          (1, 'Z1 — Recovery'),
          (2, 'Z2 — Aerobic'),
          (3, 'Z3 — Tempo'),
          (4, 'Z4 — Threshold'),
          (5, 'Z5 — VO2max'),
        ])
          (
            label: name,
            selected: _selectedZone == z,
            onTap: () => setState(() => _selectedZone = z),
          ),
      ],
    );
  }

  void _showTypeFilter() {
    _showFilterSheet(
      title: 'Type',
      options: [
        (
          label: 'Any',
          selected: _selectedType == null,
          onTap: () => setState(() => _selectedType = null),
        ),
        (
          label: 'Distance',
          selected: _selectedType == WorkoutType.singleDistance,
          onTap: () => setState(() => _selectedType = WorkoutType.singleDistance),
        ),
        (
          label: 'Time',
          selected: _selectedType == WorkoutType.singleTime,
          onTap: () => setState(() => _selectedType = WorkoutType.singleTime),
        ),
        (
          label: 'Intervals',
          selected: _selectedType == WorkoutType.intervals,
          onTap: () => setState(() => _selectedType = WorkoutType.intervals),
        ),
        (
          label: 'Variable',
          selected: _selectedType == WorkoutType.variableIntervals,
          onTap: () => setState(() => _selectedType = WorkoutType.variableIntervals),
        ),
      ],
    );
  }

  String _durationLabel() {
    return switch (_selectedDuration) {
      null => 'Duration',
      DurationFilter.under30 => '<30m',
      DurationFilter.from30to60 => '30–60m',
      DurationFilter.over60 => '60m+',
    };
  }

  String _zoneLabel() {
    if (_selectedZone == null) return 'Zone';
    return 'Z$_selectedZone';
  }

  String _typeLabel() {
    return switch (_selectedType) {
      null => 'Type',
      WorkoutType.singleDistance => 'Distance',
      WorkoutType.singleTime => 'Time',
      WorkoutType.intervals => 'Intervals',
      WorkoutType.variableIntervals => 'Variable',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workoutsAsync = ref.watch(filteredWorkoutsProvider((
      search: _searchController.text,
      type: _selectedType,
      tag: null,
      duration: _selectedDuration,
      hrZone: _selectedZone,
      sort: _sortOrder,
    )));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          _SortButton(
            current: _sortOrder,
            onSelected: (order) => setState(() => _sortOrder = order),
          ),
          const BleStatusButton(),
        ],
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

          // Filter dropdown buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _FilterButton(
                  label: _durationLabel(),
                  active: _selectedDuration != null,
                  onTap: _showDurationFilter,
                )),
                const SizedBox(width: 8),
                Expanded(child: _FilterButton(
                  label: _zoneLabel(),
                  active: _selectedZone != null,
                  onTap: _showZoneFilter,
                )),
                const SizedBox(width: 8),
                Expanded(child: _FilterButton(
                  label: _typeLabel(),
                  active: _selectedType != null,
                  onTap: _showTypeFilter,
                )),
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
                      ],
                    ),
                  );
                }

                // WOD: only show when no filters active
                final allWorkouts =
                    ref.watch(workoutLibraryProvider).valueOrNull ?? [];

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
                if (!_hasFilters && wodPool.isNotEmpty) {
                  final wodIdx = getWodIndex(wodPool.length,
                      shuffleOffset: _wodShuffleOffset);
                  wodWorkout = wodPool[wodIdx];
                }

                final wod = wodWorkout;
                final displayWorkouts = wod != null && workouts.length > 1
                    ? workouts
                        .where((w) => w.id != wod.id)
                        .toList()
                    : workouts;

                return RefreshIndicator(
                  onRefresh: () async {
                    final repo = ref.read(workoutRepositoryProvider);
                    await repo.refreshWorkouts(isPublic: true);
                    ref.read(workoutRefreshTriggerProvider.notifier).state++;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: displayWorkouts.length + (wod != null ? 1 : 0),
                    itemBuilder: (context, index) {
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
}

/// A compact dropdown-style filter button.
class _FilterButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? RowCraftTheme.primaryBlue.withValues(alpha: 0.15)
          : RowCraftTheme.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? RowCraftTheme.primaryBlue
                  : RowCraftTheme.subtleGrey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? RowCraftTheme.primaryBlue : Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: active ? RowCraftTheme.primaryBlue : RowCraftTheme.subtleGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sort popup menu button shown in the AppBar.
class _SortButton extends StatelessWidget {
  final LibrarySortOrder current;
  final ValueChanged<LibrarySortOrder> onSelected;

  const _SortButton({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDefault = current == LibrarySortOrder.newest;
    return PopupMenuButton<LibrarySortOrder>(
      icon: Badge(
        isLabelVisible: !isDefault,
        child: const Icon(Icons.sort),
      ),
      tooltip: 'Sort',
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (_) => [
        _sortItem(LibrarySortOrder.newest, 'Newest', current),
        _sortItem(LibrarySortOrder.duration, 'Duration', current),
        _sortItem(LibrarySortOrder.mostForked, 'Most Forked', current),
      ],
    );
  }

  PopupMenuItem<LibrarySortOrder> _sortItem(
    LibrarySortOrder value,
    String label,
    LibrarySortOrder current,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (value == current)
            const Icon(Icons.check, size: 16)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// Workout card with duration as hero element.
class _WorkoutCard extends StatelessWidget {
  final Workout workout;

  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalDist = computeTotalDistance(workout.segments);
    final totalTime = computeTotalTime(workout.segments);
    final estimatedSecs = computeEstimatedTotalTime(workout.segments, kDefaultFtpWatts);
    final dominantZone = computeDominantZone(workout.segments);

    // Hero value: distance for distance workouts, time for everything else
    final heroValue = workout.workoutType == WorkoutType.singleDistance
        ? formatDistance(totalDist ?? 0)
        : formatDuration(totalTime ?? estimatedSecs);

    const zoneColors = {
      1: RowCraftTheme.hrZone1,
      2: RowCraftTheme.hrZone2,
      3: RowCraftTheme.hrZone3,
      4: RowCraftTheme.hrZone4,
      5: RowCraftTheme.hrZone5,
    };

    return Card(
      child: InkWell(
        onTap: () => context.push('/workout/${workout.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero row: duration + type badge + zone
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    heroValue,
                    style: theme.textTheme.displaySmall,
                  ),
                  const Spacer(),
                  WorkoutTypeBadge(type: workout.workoutType),
                  if (dominantZone != null && zoneColors.containsKey(dominantZone)) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: zoneColors[dominantZone]!.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Z$dominantZone',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: zoneColors[dominantZone],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Segment graph
              WorkoutGraph(segments: workout.segments, height: 48),

              const SizedBox(height: 10),

              // Title
              Text(
                workout.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              // Metadata + tags
              Row(
                children: [
                  // Tags
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: workout.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: RowCraftTheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: RowCraftTheme.subtleGrey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Metadata
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.segment,
                          size: 12, color: RowCraftTheme.subtleGrey),
                      const SizedBox(width: 3),
                      Text(
                        '${workout.segments.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: RowCraftTheme.subtleGrey,
                        ),
                      ),
                      if (workout.forkCount > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.fork_right,
                            size: 12, color: RowCraftTheme.subtleGrey),
                        const SizedBox(width: 3),
                        Text(
                          '${workout.forkCount}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: RowCraftTheme.subtleGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
