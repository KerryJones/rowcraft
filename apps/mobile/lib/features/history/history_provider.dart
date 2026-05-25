import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/workout_result.dart';
import '../../services/local_db.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../utils/number_format.dart';
import '../../utils/pace_utils.dart';
import '../../utils/workout_utils.dart';

enum SyncStatus { synced, pending, failed }

/// Wraps a workout result with its current sync status.
class HistoryEntry {
  final WorkoutResult result;
  final SyncStatus status;

  /// SQLite row id for pending entries — used to drive retry/discard actions.
  final int? pendingRowId;

  /// Number of failed sync attempts (pending only).
  final int attempts;

  const HistoryEntry({
    required this.result,
    required this.status,
    this.pendingRowId,
    this.attempts = 0,
  });
}

/// Synced workout history from Supabase. Used by achievements/PR backfill
/// and any caller that only cares about cloud-confirmed results.
final workoutHistoryProvider =
    FutureProvider<List<WorkoutResult>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final userId = service.currentUserId;
  if (userId == null) return const [];
  return service.getResults(userId);
});

/// Merged synced (Supabase) + pending (local SQLite) workouts, sorted by
/// `startedAt` descending. UI uses this so locally-queued workouts appear
/// immediately even when offline or after a sync failure.
final workoutHistoryEntriesProvider =
    FutureProvider<List<HistoryEntry>>((ref) async {
  final db = ref.watch(localDatabaseProvider);

  // Re-evaluate when pending count changes so the list stays current.
  ref.watch(pendingSyncCountProvider);

  final synced = await ref.watch(workoutHistoryProvider.future);
  final syncedById = {for (final r in synced) r.id: r};

  final pendingRows = await db.getPendingResults();
  final pendingEntries = <HistoryEntry>[];
  for (final row in pendingRows) {
    try {
      final map = jsonDecode(row.resultJson) as Map<String, dynamic>;
      final result = WorkoutResult.fromJson(map);
      // Skip rows whose Supabase upsert already landed — they show in the
      // synced list with the proper server fields. Avoids double-rendering.
      if (result.id.isNotEmpty && syncedById.containsKey(result.id)) {
        continue;
      }
      pendingEntries.add(HistoryEntry(
        result: result,
        status: row.attempts >= 3 ? SyncStatus.failed : SyncStatus.pending,
        pendingRowId: row.id,
        attempts: row.attempts,
      ));
    } catch (e) {
      debugPrint('history: failed to decode pending row ${row.id}: $e');
    }
  }

  final entries = [
    ...synced.map(
      (r) => HistoryEntry(result: r, status: SyncStatus.synced),
    ),
    ...pendingEntries,
  ];
  entries.sort((a, b) => b.result.startedAt.compareTo(a.result.startedAt));
  return entries;
});

/// Single workout result by ID (looks across synced + pending).
final workoutResultProvider =
    FutureProvider.family<WorkoutResult?, String>((ref, resultId) async {
  final entries = await ref.watch(workoutHistoryEntriesProvider.future);
  try {
    return entries.firstWhere((e) => e.result.id == resultId).result;
  } catch (_) {
    return null;
  }
});

/// Live count of pending (locally-queued, not-yet-synced) results.
///
/// Polls every 5s but only emits when the count changes — without the
/// dedupe, every dependent provider (history list, summary) rebuilds on
/// each tick even when nothing happened.
final pendingSyncCountProvider = StreamProvider<int>((ref) async* {
  final sync = ref.watch(syncServiceProvider);
  int? last;
  final initial = await sync.pendingCount;
  last = initial;
  yield initial;
  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    final next = await sync.pendingCount;
    if (next == last) continue;
    last = next;
    yield next;
  }
});

/// Summary statistics across all results (synced + pending).
final historySummaryProvider = FutureProvider<HistorySummary>((ref) async {
  final entries = await ref.watch(workoutHistoryEntriesProvider.future);
  return HistorySummary.fromResults(entries.map((e) => e.result).toList());
});

class HistorySummary {
  final int totalWorkouts;
  final double totalDistance;
  final Duration totalTime;
  final int? bestSplit;
  final double avgStrokeRate;
  final int activeDays;
  final int totalCalories;
  final int avgWatts;
  final int avgPaceWeighted;

  const HistorySummary({
    required this.totalWorkouts,
    required this.totalDistance,
    required this.totalTime,
    this.bestSplit,
    required this.avgStrokeRate,
    required this.activeDays,
    required this.totalCalories,
    required this.avgWatts,
    required this.avgPaceWeighted,
  });

  factory HistorySummary.fromResults(List<WorkoutResult> results) {
    if (results.isEmpty) {
      return const HistorySummary(
        totalWorkouts: 0,
        totalDistance: 0,
        totalTime: Duration.zero,
        avgStrokeRate: 0,
        activeDays: 0,
        totalCalories: 0,
        avgWatts: 0,
        avgPaceWeighted: 0,
      );
    }

    double totalDist = 0;
    Duration totalTime = Duration.zero;
    int? bestSplit;
    int totalCalories = 0;
    final activeDates = <DateTime>{};
    // Duration-weighted accumulators — match workout_provider.dart aggregation.
    double paceWeighted = 0;
    double srWeighted = 0;
    double wattsWeighted = 0;
    double totalMs = 0;

    for (final r in results) {
      totalDist += r.totalDistance;
      totalTime += r.totalTime;
      totalCalories += r.calories;

      final localDay = r.startedAt.toLocal();
      activeDates.add(DateTime(localDay.year, localDay.month, localDay.day));

      final ms = r.totalTime.inMilliseconds.toDouble();
      if (ms > 0) {
        paceWeighted += r.avgSplit * ms;
        srWeighted += r.avgStrokeRate * ms;
        wattsWeighted += r.avgWatts * ms;
        totalMs += ms;
      }

      if (r.avgSplit > 0) {
        if (bestSplit == null || r.avgSplit < bestSplit) {
          bestSplit = r.avgSplit;
        }
      }
    }

    final hasDuration = totalMs > 0;
    return HistorySummary(
      totalWorkouts: results.length,
      totalDistance: totalDist,
      totalTime: totalTime,
      bestSplit: bestSplit,
      avgStrokeRate: hasDuration ? srWeighted / totalMs : 0,
      activeDays: activeDates.length,
      totalCalories: totalCalories,
      avgWatts: hasDuration ? (wattsWeighted / totalMs).round() : 0,
      avgPaceWeighted: hasDuration ? (paceWeighted / totalMs).round() : 0,
    );
  }

  String get totalDistanceFormatted {
    if (totalDistance >= 1000000) {
      return '${formatThousands((totalDistance / 1000).round())}km';
    }
    if (totalDistance >= 1000) {
      return '${(totalDistance / 1000).toStringAsFixed(1)}km';
    }
    return '${formatThousandsIfLarge(totalDistance.toInt())}m';
  }

  String get bestSplitFormatted => formatPace(bestSplit ?? 0);

  String get avgPaceWeightedFormatted => formatPace(avgPaceWeighted);

  String get totalTimeFormatted => formatDuration(totalTime.inSeconds);
}
