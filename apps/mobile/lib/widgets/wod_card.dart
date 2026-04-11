import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../models/workout.dart';
import '../utils/pace_utils.dart';
import '../utils/workout_utils.dart' as wu;
import 'workout_graph.dart';

/// Amber-themed Workout of the Day card.
class WodCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;
  final VoidCallback onShuffle;
  final bool canShuffle;
  final int ftpWatts;

  const WodCard({
    super.key,
    required this.workout,
    required this.onTap,
    required this.onShuffle,
    this.canShuffle = true,
    this.ftpWatts = kDefaultFtpWatts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalTime = wu.computeEstimatedTotalTime(
        workout.segments, ftpWatts);
    final segmentCount = wu.computeSegmentCount(workout.segments);
    final avgIntensity = wu.computeAvgIntensity(workout.segments);
    final avgPace = avgIntensity != null
        ? intensityToPaceTenths(avgIntensity, ftpWatts)
        : null;

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

            // Title
            Text(
              workout.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _StatItem(
                  label: 'TIME',
                  value: totalTime > 0
                      ? wu.formatDuration(totalTime)
                      : '—',
                ),
                const SizedBox(width: 20),
                _StatItem(label: 'SEGMENTS', value: '$segmentCount'),
                const SizedBox(width: 20),
                _StatItem(
                  label: 'AVG PACE',
                  value: avgPace != null ? wu.formatPace(avgPace) : '—',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segment graph
            WorkoutGraph(segments: workout.segments, height: 80),

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

/// Pick a WOD index. Each day selects a different workout; shuffle steps
/// through the list so every tap guarantees a new one.
int getWodIndex(int workoutCount, {int shuffleOffset = 0}) {
  if (workoutCount <= 0) return 0;
  final day = DateTime.now().toUtc().difference(DateTime.utc(2025)).inDays;
  return (day + shuffleOffset) % workoutCount;
}
