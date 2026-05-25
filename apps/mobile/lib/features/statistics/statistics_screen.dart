import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../utils/hr_zones.dart';
import '../../utils/number_format.dart';
import '../../utils/time_in_zone.dart';
import '../../widgets/content_constraint.dart';
import '../../widgets/hr_zone_donut.dart';
import '../../widgets/metric_tile.dart';
import '../history/history_provider.dart';
import '../profile/profile_screen.dart' show profileProvider;

/// All-time time-in-zone aggregated across every saved workout's `timeSamples`.
/// Memoized so the per-sample loop doesn't re-run on unrelated rebuilds.
final allTimeZoneDistributionProvider =
    FutureProvider<Map<int, double>>((ref) async {
  final entries = await ref.watch(workoutHistoryEntriesProvider.future);
  final profile = await ref.watch(profileProvider.future);
  final maxHr = profile.maxHeartRate ?? 190;
  final restingHr = profile.restingHeartRate;
  return aggregateTimeInZone(
    entries.map((e) => e.result.timeSamples),
    restingHr,
    maxHr,
  );
});

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(historySummaryProvider);
    final zonesAsync = ref.watch(allTimeZoneDistributionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: 'Failed to load statistics',
          onRetry: () => ref.invalidate(historySummaryProvider),
        ),
        data: (summary) {
          if (summary.totalWorkouts == 0) {
            return const _EmptyState();
          }
          return ContentConstraint(
            child: _StatisticsBody(
              summary: summary,
              aggregateTimeInZone: zonesAsync.value ?? const {},
            ),
          );
        },
      ),
    );
  }
}

class _StatisticsBody extends StatelessWidget {
  final HistorySummary summary;
  final Map<int, double> aggregateTimeInZone;

  const _StatisticsBody({
    required this.summary,
    required this.aggregateTimeInZone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Time', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${summary.totalWorkouts} workout${summary.totalWorkouts == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    MetricTile(
                      label: 'Total Meters',
                      value: summary.totalDistanceFormatted,
                      icon: Icons.straighten,
                    ),
                    MetricTile(
                      label: 'Total Time',
                      value: summary.totalTimeFormatted,
                      icon: Icons.schedule,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    MetricTile(
                      label: 'Active Days',
                      value: formatThousandsIfLarge(summary.activeDays),
                      icon: Icons.calendar_today,
                    ),
                    MetricTile(
                      label: 'Total Calories',
                      value: formatThousandsIfLarge(summary.totalCalories),
                      icon: Icons.local_fire_department,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    MetricTile(
                      label: 'Average Pace',
                      value: summary.avgPaceWeighted > 0
                          ? '${summary.avgPaceWeightedFormatted}/500m'
                          : '--:--',
                      icon: Icons.speed,
                    ),
                    MetricTile(
                      label: 'Average Watts',
                      value: '${summary.avgWatts}',
                      icon: Icons.bolt,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    MetricTile(
                      label: 'Average Rate',
                      value: '${summary.avgStrokeRate.round()}',
                      icon: Icons.sync,
                    ),
                    MetricTile(
                      label: 'Best Split',
                      value: summary.bestSplitFormatted,
                      icon: Icons.emoji_events_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Heart Rate Zones',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Time distribution across all workouts',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                aggregateTimeInZone.isEmpty
                    ? Text(
                        'No heart-rate data recorded yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: RowCraftTheme.subtleGrey,
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          HrZoneDonut(
                            timeInZone: aggregateTimeInZone,
                            size: 96,
                            strokeWidth: 14,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _ZoneLegend(
                              timeInZone: aggregateTimeInZone,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoneLegend extends ConsumerWidget {
  final Map<int, double> timeInZone;

  const _ZoneLegend({required this.timeInZone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final system =
        ref.watch(profileProvider).value?.zoneSystem ?? ZoneSystem.rowing;
    final total = timeInZone.values.fold<double>(0, (sum, v) => sum + v);
    if (total <= 0) {
      return const SizedBox.shrink();
    }
    // Iterate all five zones even when empty so the legend layout stays stable.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var zone = 1; zone <= 5; zone++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: zoneColor(zone),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  zoneDisplayInfo(zone, system).name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: RowCraftTheme.metricWhite,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatSeconds(timeInZone[zone] ?? 0),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: RowCraftTheme.subtleGrey,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatSeconds(double seconds) {
    final total = seconds.round();
    if (total <= 0) return '0s';
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bar_chart,
            size: 64,
            color: RowCraftTheme.subtleGrey,
          ),
          const SizedBox(height: 16),
          Text(
            'No workouts yet',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: RowCraftTheme.subtleGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Finish a workout to see your stats',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: RowCraftTheme.errorRose,
          ),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
