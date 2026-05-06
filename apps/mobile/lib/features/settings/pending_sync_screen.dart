import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../models/workout_result.dart';
import '../../services/local_db.dart';
import '../../services/plexo_service.dart';
import '../../services/sync_service.dart';
import '../history/history_provider.dart';
import '../profile/profile_screen.dart'
    show c2LinkedProvider, stravaLinkedProvider;

/// Pending rows in the local sync queue. Re-evaluates whenever the
/// pending count changes (retry, discard, background sync).
final _pendingRowsProvider = FutureProvider<List<PendingResult>>((ref) async {
  ref.watch(pendingSyncCountProvider);
  return ref.watch(localDatabaseProvider).getPendingResults();
});

/// Lists locally-queued workout results that haven't fully synced yet.
/// Lets the user trigger a retry or discard a stuck row.
class PendingSyncScreen extends ConsumerStatefulWidget {
  const PendingSyncScreen({super.key});

  @override
  ConsumerState<PendingSyncScreen> createState() => _PendingSyncScreenState();
}

class _PendingSyncScreenState extends ConsumerState<PendingSyncScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      await ref.read(syncServiceProvider).syncPendingResults();
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(workoutHistoryEntriesProvider);
      ref.invalidate(_pendingRowsProvider);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _discard(int rowId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RowCraftTheme.surfaceContainer,
        title: const Text('Discard queued workout?'),
        content: const Text(
          'This will permanently delete the locally-saved workout. '
          'It has not synced to the cloud yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: RowCraftTheme.errorRose,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(localDatabaseProvider).discardPending(rowId);
    ref.invalidate(workoutHistoryEntriesProvider);
    ref.invalidate(_pendingRowsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(_pendingRowsProvider);
    final lastError = ref.watch(syncServiceProvider).lastError;

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Sync')),
      body: rowsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_done_outlined,
                    size: 64,
                    color: RowCraftTheme.successGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All workouts synced',
                    style: GoogleFonts.inter(
                      color: RowCraftTheme.metricWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (lastError != null)
                Card(
                  color: RowCraftTheme.errorRose.withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Last error: $lastError',
                      style: const TextStyle(color: RowCraftTheme.errorRose),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: _retrying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Retry now'),
                ),
              ),
              const SizedBox(height: 16),
              ...rows.map((row) => _PendingRowCard(
                    row: row,
                    onDiscard: () => _discard(row.id),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _PendingRowCard extends ConsumerWidget {
  final PendingResult row;
  final VoidCallback onDiscard;

  const _PendingRowCard({required this.row, required this.onDiscard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title = 'Workout';
    String subtitle = '';
    try {
      final map = jsonDecode(row.resultJson) as Map<String, dynamic>;
      final result = WorkoutResult.fromJson(map);
      title = result.displayName;
      subtitle =
          '${result.totalDistance.toInt()}m · ${result.totalTimeFormatted}';
    } catch (_) {}

    final queued = DateFormat('MMM d, h:mm a').format(row.queuedAt);

    // Only show targets the user is actually connected to. A row that
    // hasn't been processed by the sync pass yet has all flags false;
    // we don't want to display "Plexo, Strava" to a user who has neither.
    final c2Linked = ref.watch(c2LinkedProvider).value ?? false;
    final stravaLinked = ref.watch(stravaLinkedProvider).value ?? false;
    final plexoEnabled =
        ref.watch(plexoEnabledProvider).value ?? false;

    final flags = [
      if (!row.syncedToSupabase) 'Cloud',
      if (c2Linked && !row.syncedToC2) 'C2',
      if (plexoEnabled && !row.syncedToPlexo) 'Plexo',
      if (stravaLinked && !row.syncedToStrava) 'Strava',
    ].join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: RowCraftTheme.metricWhite,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  style: const TextStyle(color: RowCraftTheme.subtleGrey),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Queued $queued · ${row.attempts} ${row.attempts == 1 ? "attempt" : "attempts"}',
              style: const TextStyle(
                color: RowCraftTheme.subtleGrey,
                fontSize: 12,
              ),
            ),
            if (flags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Pending: $flags',
                  style: const TextStyle(
                    color: RowCraftTheme.subtleGrey,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDiscard,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Discard'),
                style: TextButton.styleFrom(
                  foregroundColor: RowCraftTheme.errorRose,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
