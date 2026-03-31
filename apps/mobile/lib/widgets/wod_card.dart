import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../models/workout.dart';
import '../models/workout_segment.dart';
import 'workout_graph.dart';

/// Amber-themed Workout of the Day card.
class WodCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;
  final VoidCallback onShuffle;
  final bool canShuffle;

  const WodCard({
    super.key,
    required this.workout,
    required this.onTap,
    required this.onShuffle,
    this.canShuffle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalTime = _computeTotalTime(workout.segments);
    final totalDistance = _computeTotalDistance(workout.segments);
    final segmentCount = _computeSegmentCount(workout.segments);
    final avgPace = _computeAvgPace(workout.segments);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: RowCraftTheme.warningAmber.withValues(alpha: 0.3),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                RowCraftTheme.warningAmber.withValues(alpha: 0.1),
                RowCraftTheme.surfaceContainer,
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.local_fire_department,
                    size: 18, color: RowCraftTheme.warningAmber),
                const SizedBox(width: 6),
                Text(
                  'WORKOUT OF THE DAY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: RowCraftTheme.warningAmber,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (canShuffle) Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onShuffle();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: RowCraftTheme.warningAmber
                                .withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shuffle, size: 14,
                              color: RowCraftTheme.warningAmber),
                          const SizedBox(width: 4),
                          Text(
                            'Shuffle',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: RowCraftTheme.warningAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Type badge + title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: RowCraftTheme.warningAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    workout.workoutType.displayName,
                    style: const TextStyle(
                      color: RowCraftTheme.warningAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    workout.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _StatItem(
                  label: totalTime != null ? 'TIME' : 'DISTANCE',
                  value: totalTime != null
                      ? _formatDuration(totalTime)
                      : totalDistance != null
                          ? '${totalDistance.toInt()}m'
                          : '—',
                ),
                const SizedBox(width: 20),
                _StatItem(label: 'SEGMENTS', value: '$segmentCount'),
                const SizedBox(width: 20),
                _StatItem(
                  label: 'AVG PACE',
                  value: avgPace != null ? _formatPace(avgPace) : '—',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segment graph
            WorkoutGraph(segments: workout.segments, height: 80),

            // Description
            if (workout.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                workout.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RowCraftTheme.subtleGrey,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Tags
            if (workout.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: workout.tags.take(4).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: RowCraftTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                          fontSize: 11, color: RowCraftTheme.subtleGrey),
                    ),
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

  static int? _computeTotalTime(List<WorkoutSegment> segments) {
    var total = 0.0;
    var hasTime = false;
    for (final seg in segments) {
      if (seg.durationType == DurationType.time) {
        total += seg.durationValue * seg.repeat;
        hasTime = true;
      }
    }
    return hasTime ? total.toInt() : null;
  }

  static double? _computeTotalDistance(List<WorkoutSegment> segments) {
    var total = 0.0;
    var hasDist = false;
    for (final seg in segments) {
      if (seg.durationType == DurationType.distance) {
        total += seg.durationValue * seg.repeat;
        hasDist = true;
      }
    }
    return hasDist ? total : null;
  }

  static int _computeSegmentCount(List<WorkoutSegment> segments) {
    return segments.fold(0, (sum, seg) => sum + seg.repeat);
  }

  static int? _computeAvgPace(List<WorkoutSegment> segments) {
    final workSegs = segments
        .where((s) => s.type == SegmentType.work && s.targetSplit != null);
    if (workSegs.isEmpty) return null;
    var totalWeight = 0.0;
    var weightedSum = 0.0;
    for (final s in workSegs) {
      final weight = s.durationValue * s.repeat;
      weightedSum += s.targetSplit!.min * weight;
      totalWeight += weight;
    }
    return totalWeight > 0 ? (weightedSum / totalWeight).round() : null;
  }

  static String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String _formatPace(int tenths) {
    final minutes = tenths ~/ 600;
    final secs = (tenths % 600) ~/ 10;
    final t = tenths % 10;
    return '$minutes:${secs.toString().padLeft(2, '0')}.$t';
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

/// Pick a WOD index. Each day selects a different workout; shuffle steps
/// through the list so every tap guarantees a new one.
int getWodIndex(int workoutCount, {int shuffleOffset = 0}) {
  if (workoutCount <= 0) return 0;
  final day = DateTime.now().toUtc().difference(DateTime.utc(2025)).inDays;
  return (day + shuffleOffset) % workoutCount;
}
