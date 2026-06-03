import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../utils/time_in_zone.dart';
import '../../widgets/content_constraint.dart';
import '../../widgets/hr_zone_donut.dart';
import '../../widgets/status_chip.dart';
import '../profile/profile_screen.dart';
import 'history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(workoutHistoryEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
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

          final grouped = _groupByDate(entries);

          return ContentConstraint(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(workoutHistoryProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final entry = grouped.entries.elementAt(index);
                  return _DateGroup(date: entry.key, entries: entry.value);
                },
              ),
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

  Map<String, List<HistoryEntry>> _groupByDate(List<HistoryEntry> entries) {
    final map = <String, List<HistoryEntry>>{};
    final formatter = DateFormat('EEEE, MMMM d');

    for (final e in entries) {
      final key = formatter.format(e.result.startedAt);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }
}

class _DateGroup extends StatelessWidget {
  final String date;
  final List<HistoryEntry> entries;

  const _DateGroup({required this.date, required this.entries});

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
        ...entries.map((entry) => _ResultCard(entry: entry)),
      ],
    );
  }
}

class _ResultCard extends ConsumerWidget {
  final HistoryEntry entry;

  const _ResultCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('h:mm a');
    final result = entry.result;
    final isPending = entry.status != SyncStatus.synced;
    final profile = ref.watch(profileProvider).value;
    final maxHr = profile?.maxHeartRate;
    final canShowDonut = maxHr != null &&
        maxHr > 0 &&
        hasHrSamples(result.timeSamples);
    final zoneDist = canShowDonut
        ? timeInZone(result.timeSamples, profile?.restingHeartRate, maxHr)
        : const <int, double>{};
    final canRedo = result.workoutId != null;

    return Card(
      child: InkWell(
        // Pending rows have no Supabase id yet — detail screen looks up by id.
        onTap: isPending && result.id.isEmpty
            ? null
            : () => context.push('/history/${result.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    timeFormat.format(result.startedAt),
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  _SyncBadge(status: entry.status),
                  if (entry.status == SyncStatus.synced && result.syncedToC2)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: StatusChip(
                        label: 'C2 Synced',
                        color: RowCraftTheme.successGreen,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(result.displayName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),

              Row(
                children: [
                  _MetricCell(
                    value: '${result.totalDistance.toInt()}m',
                    label: 'Distance',
                  ),
                  const SizedBox(width: 16),
                  _MetricCell(value: result.totalTimeFormatted, label: 'Time'),
                  const SizedBox(width: 16),
                  _MetricCell(
                    value: result.avgSplitFormatted,
                    label: 'Avg pace',
                    highlight: true,
                  ),
                  const Spacer(),
                  _MetricCell(value: '${result.avgStrokeRate}', label: 's/m'),
                  if (canShowDonut) ...[
                    const SizedBox(width: 8),
                    HrZoneDonut(
                      timeInZone: zoneDist,
                      size: 28,
                      strokeWidth: 4,
                    ),
                  ],
                ],
              ),

              if (result.splits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${result.splits.length} splits',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (canRedo) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Repeat workout'),
                    onPressed: () =>
                        context.push('/workout/${result.workoutId}'),
                    style: TextButton.styleFrom(
                      foregroundColor: RowCraftTheme.primaryBlue,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  final SyncStatus status;
  const _SyncBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SyncStatus.synced:
        return const SizedBox.shrink();
      case SyncStatus.pending:
        return const StatusChip(
          label: 'Syncing…',
          color: RowCraftTheme.primaryBlue,
        );
      case SyncStatus.failed:
        return const StatusChip(
          label: 'Sync failed',
          color: RowCraftTheme.errorRose,
        );
    }
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
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
