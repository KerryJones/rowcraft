import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../models/workout_result.dart';
import 'history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resultsAsync = ref.watch(workoutHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: resultsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
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
                    'Complete your first workout to see it here',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          // Group results by date
          final grouped = _groupByDate(results);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(workoutHistoryProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                return _DateGroup(
                  date: entry.key,
                  results: entry.value,
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: RowCraftTheme.errorRose),
              const SizedBox(height: 16),
              Text('Failed to load history', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(workoutHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<WorkoutResult>> _groupByDate(List<WorkoutResult> results) {
    final map = <String, List<WorkoutResult>>{};
    final formatter = DateFormat('EEEE, MMMM d');

    for (final result in results) {
      final key = formatter.format(result.startedAt);
      map.putIfAbsent(key, () => []).add(result);
    }
    return map;
  }
}

class _DateGroup extends StatelessWidget {
  final String date;
  final List<WorkoutResult> results;

  const _DateGroup({required this.date, required this.results});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            date,
            style: theme.textTheme.labelLarge?.copyWith(
              color: RowCraftTheme.primaryBlue,
            ),
          ),
        ),
        ...results.map((result) => _ResultCard(result: result)),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final WorkoutResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm a');

    return Card(
      child: InkWell(
        onTap: () => context.push('/history/${result.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: time + sync status
              Row(
                children: [
                  Text(
                    timeFormat.format(result.startedAt),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (result.syncedToC2)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: RowCraftTheme.successGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'C2 Synced',
                        style: TextStyle(
                          color: RowCraftTheme.successGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Main metrics row
              Row(
                children: [
                  // Distance
                  _MetricCell(
                    value: '${result.totalDistance.toInt()}m',
                    label: 'Distance',
                  ),
                  const SizedBox(width: 24),

                  // Time
                  _MetricCell(
                    value: result.totalTimeFormatted,
                    label: 'Time',
                  ),
                  const SizedBox(width: 24),

                  // Avg split
                  _MetricCell(
                    value: result.avgSplitFormatted,
                    label: '/500m',
                    highlight: true,
                  ),
                  const Spacer(),

                  // Stroke rate
                  _MetricCell(
                    value: '${result.avgStrokeRate}',
                    label: 'spm',
                  ),
                ],
              ),

              // Split count
              if (result.splits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${result.splits.length} splits',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String value;
  final String label;
  final bool highlight;

  const _MetricCell({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: highlight ? RowCraftTheme.primaryBlue : null,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}
