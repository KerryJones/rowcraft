import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/workout.dart';
import '../../models/workout_segment.dart';
import '../../services/supabase_service.dart';
import '../../utils/pace_utils.dart' show intensityToPaceTenths, kDefaultFtpWatts;
import '../../utils/segment_color.dart';
import '../../utils/segment_display.dart';
import '../../utils/workout_utils.dart';
import '../../widgets/connection_required_dialog.dart';
import '../../widgets/difficulty_indicator.dart';
import '../../widgets/workout_graph.dart';
import '../../widgets/workout_type_badge.dart';
import '../ble/ble_provider.dart';
import '../ble/pm5_service.dart';
import '../library/library_provider.dart';

/// Pre-workout screen showing workout details with a "Begin Workout" CTA.
/// Hardware connection is handled via modal if PM5 is not connected.
class PreWorkoutScreen extends ConsumerStatefulWidget {
  final String workoutId;
  final String? planId;
  final int? planWeek;
  final int? planSession;

  const PreWorkoutScreen({
    super.key,
    required this.workoutId,
    this.planId,
    this.planWeek,
    this.planSession,
  });

  @override
  ConsumerState<PreWorkoutScreen> createState() => _PreWorkoutScreenState();
}

class _PreWorkoutScreenState extends ConsumerState<PreWorkoutScreen> {
  Workout? _workout;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  Future<void> _loadWorkout() async {
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final workout = await supabase.getWorkout(widget.workoutId);
      if (mounted) {
        setState(() {
          _workout = workout;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load workout: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startWorkout() {
    final queryParams = <String, String>{};
    if (widget.planId != null) queryParams['plan'] = widget.planId!;
    if (widget.planWeek != null) {
      queryParams['week'] = widget.planWeek.toString();
    }
    if (widget.planSession != null) {
      queryParams['session'] = widget.planSession.toString();
    }
    final uri = Uri(
      path: '/workout/${widget.workoutId}/active',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    context.go(uri.toString());
  }

  void _handleBeginWorkout() {
    final bleState = ref.read(bleProvider);
    if (bleState.pm5ConnectionState == PM5ConnectionState.connected) {
      _startWorkout();
    } else {
      showConnectionRequiredSheet(
        context: context,
        onConnected: _startWorkout,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: RowCraftTheme.surfaceDark,
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: RowCraftTheme.surfaceDark,
        appBar: AppBar(title: const Text('Workout')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(color: RowCraftTheme.errorRose),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _loadWorkout();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final workout = _workout!;

    return Scaffold(
      backgroundColor: RowCraftTheme.surfaceDark,
      appBar: AppBar(title: const Text('Workout')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _WorkoutDetailBody(workout: workout),
                  const SizedBox(height: 24),
                  _SimilarWorkoutsSection(workout: workout),
                ],
              ),
            ),

            // BEGIN WORKOUT button
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: RowCraftTheme.surfaceContainer,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _handleBeginWorkout,
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: const Text(
                    'BEGIN WORKOUT',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RowCraftTheme.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutDetailBody extends StatelessWidget {
  final Workout workout;

  const _WorkoutDetailBody({required this.workout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = workout.segments;

    final totalTime = computeTotalTime(segments);
    final totalDist = computeTotalDistance(segments);
    final segCount = computeSegmentCount(segments);
    final avgIntensity = computeAvgIntensity(segments);
    final avgPace = avgIntensity != null
        ? intensityToPaceTenths(avgIntensity, kDefaultFtpWatts)
        : null;

    // Collect HR zones from segments
    final hrZones = <int>{};
    for (final seg in segments) {
      if (seg.targetHrZone != null) hrZones.add(seg.targetHrZone!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(workout.title, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),

        // Difficulty + type badge
        Row(
          children: [
            DifficultyIndicator.fromSegments(segments: segments),
            const SizedBox(width: 12),
            WorkoutTypeBadge(type: workout.workoutType),
          ],
        ),

        // Description
        if (workout.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            workout.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: RowCraftTheme.subtleGrey,
            ),
          ),
        ],

        // Segment graph
        const SizedBox(height: 20),
        WorkoutGraph(segments: segments, height: 140),

        // Stats row
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            if (totalTime != null)
              _StatItem(label: 'DURATION', value: formatDuration(totalTime)),
            if (totalDist != null)
              _StatItem(
                  label: 'DISTANCE', value: formatDistance(totalDist)),
            _StatItem(
              label: 'SEGMENTS',
              value: '$segCount',
            ),
            if (avgPace != null)
              _StatItem(
                  label: 'AVG PACE', value: '${formatPace(avgPace)}/500m'),
          ],
        ),

        // Segment list
        if (segments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Segments',
              style: theme.textTheme.labelLarge?.copyWith(
                  color: RowCraftTheme.subtleGrey)),
          const SizedBox(height: 8),
          ...segments.map((seg) => _SegmentRow(segment: seg)),
        ],

        // HR Zone chips
        if (hrZones.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Target HR Zones',
              style: theme.textTheme.labelLarge?.copyWith(
                  color: RowCraftTheme.subtleGrey)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: (hrZones.toList()..sort()).map((zone) {
              final color = _hrZoneColor(zone);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Zone $zone',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        ],

        // Tags
        if (workout.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: workout.tags.map((tag) {
              return Chip(
                label: Text(tag, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  static Color _hrZoneColor(int zone) {
    return switch (zone) {
      1 => RowCraftTheme.hrZone1,
      2 => RowCraftTheme.hrZone2,
      3 => RowCraftTheme.hrZone3,
      4 => RowCraftTheme.hrZone4,
      5 => RowCraftTheme.hrZone5,
      _ => RowCraftTheme.subtleGrey,
    };
  }
}

class _SegmentRow extends StatelessWidget {
  final WorkoutSegment segment;

  const _SegmentRow({required this.segment});

  @override
  Widget build(BuildContext context) {
    final color = segmentDisplayColor(segment);
    final paceLabel = segmentPaceLabel(segment, kDefaultFtpWatts);
    final srLabel = segmentStrokeRateLabel(segment);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        decoration: BoxDecoration(
          color: RowCraftTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        paceLabel,
                        style: TextStyle(
                          color: segment.targetIntensity == null
                              ? RowCraftTheme.subtleGrey
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (srLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '| $srLabel',
                          style: const TextStyle(
                            color: RowCraftTheme.subtleGrey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        segment.durationLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: RowCraftTheme.subtleGrey,
            fontSize: 9,
            letterSpacing: 1.0,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SimilarWorkoutsSection extends ConsumerWidget {
  final Workout workout;

  const _SimilarWorkoutsSection({required this.workout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workout.tags.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final similarAsync = ref.watch(similarWorkoutsProvider(
      (workoutId: workout.id, tags: workout.tags),
    ));

    return similarAsync.when(
      data: (similar) {
        if (similar.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Similar Workouts',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: similar.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _SimilarWorkoutCard(workout: similar[index]);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SimilarWorkoutCard extends StatelessWidget {
  final Workout workout;

  const _SimilarWorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/workout/${workout.id}'),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RowCraftTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            WorkoutGraph(segments: workout.segments, height: 32),
            const SizedBox(height: 8),
            Row(
              children: [
                DifficultyIndicator.fromSegments(
                    segments: workout.segments, size: 12),
                const SizedBox(width: 8),
                WorkoutTypeBadge(type: workout.workoutType),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
