import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/workout.dart';
import '../utils/app_log.dart';
import 'local_db.dart';
import 'supabase_service.dart';

/// How old lastFullSyncAt must be before triggering another full sync.
const _fullSyncMaxAge = Duration(hours: 24);

/// Scope-specific metadata keys prevent public and user sync state from
/// stomping on each other.
String _syncedKey({bool? isPublic, String? authorId}) {
  if (isPublic == true) return 'public_workouts_last_synced_at';
  if (authorId != null) return 'my_workouts_${authorId}_last_synced_at';
  return 'workouts_last_synced_at';
}

String _fullSyncKey({bool? isPublic, String? authorId}) {
  if (isPublic == true) return 'public_workouts_last_full_sync_at';
  if (authorId != null) return 'my_workouts_${authorId}_last_full_sync_at';
  return 'workouts_last_full_sync_at';
}

/// Cache-first workout data layer.
///
/// Reads from SQLite instantly; refreshes from Supabase in the background.
/// All writes go to Supabase then update the cache (write-through).
///
/// Full sync runs on first launch and every 24 h per scope to detect remote
/// deletions. Scoping (isPublic / authorId) is applied in Dart when purging
/// stale entries so public-library syncs never evict user-owned workouts.
class WorkoutRepository {
  final LocalDatabase _db;
  final SupabaseService _supabase;

  WorkoutRepository(this._db, this._supabase);

  // ── Reads ────────────────────────────────────────────────────────────

  /// Returns cached workouts. Optionally filter by [isPublic] or [authorId].
  Future<List<Workout>> getWorkouts({
    bool? isPublic,
    String? authorId,
  }) async {
    final rows = await _db.getAllCachedWorkouts();
    final workouts = rows
        .map((r) => Workout.fromJson(
              jsonDecode(r.workoutJson) as Map<String, dynamic>,
            ))
        .toList();

    var result = workouts;
    if (isPublic != null) {
      result = result.where((w) => w.isPublic == isPublic).toList();
    }
    if (authorId != null) {
      result = result.where((w) => w.authorId == authorId).toList();
    }
    return result;
  }

  /// Fetches fresh data from Supabase, updates the cache, and returns the
  /// updated list. Returns null on network failure — caller should read from
  /// cache instead.
  ///
  /// - First call per scope: full fetch of all matching workouts.
  /// - Subsequent calls: incremental (only workouts updated since last sync).
  /// - Every 24 h per scope: also fetches remote IDs to detect and purge
  ///   deleted workouts. Deletion is scoped — only removes cached entries
  ///   that match the current [isPublic] / [authorId] filter.
  ///
  /// Pass [minInterval] to skip network entirely if the last sync was recent.
  /// Background refreshes use `Duration(minutes: 5)` to avoid redundant calls.
  Future<List<Workout>?> refreshWorkouts({
    bool? isPublic,
    String? authorId,
    Duration minInterval = Duration.zero,
  }) async {
    final syncedKey = _syncedKey(isPublic: isPublic, authorId: authorId);
    final fullSyncKey = _fullSyncKey(isPublic: isPublic, authorId: authorId);

    final lastSyncedStr = await _db.getSyncMeta(syncedKey);
    final lastFullSyncStr = await _db.getSyncMeta(fullSyncKey);

    // Skip if last sync was too recent (prevents double calls after pull-to-refresh).
    if (minInterval > Duration.zero && lastSyncedStr != null) {
      final age = DateTime.now().difference(DateTime.parse(lastSyncedStr));
      if (age < minInterval) return null;
    }

    final needsFullSync = lastFullSyncStr == null ||
        DateTime.now().difference(DateTime.parse(lastFullSyncStr)) >
            _fullSyncMaxAge;

    try {
      List<Workout> fetched;
      if (lastSyncedStr == null) {
        fetched = await _supabase.getWorkouts(
          isPublic: isPublic,
          authorId: authorId,
        );
      } else {
        fetched = await _supabase.getWorkoutsUpdatedSince(
          DateTime.parse(lastSyncedStr),
          isPublic: isPublic,
          authorId: authorId,
        );
      }

      await _cacheWorkoutList(fetched);
      await _db.setSyncMeta(syncedKey, DateTime.now().toIso8601String());

      if (needsFullSync) {
        final remoteIds = (await _supabase.getWorkoutIds(
          isPublic: isPublic,
          authorId: authorId,
        ))
            .toSet();
        await _reconcileScoped(
          remoteIds: remoteIds,
          isPublic: isPublic,
          authorId: authorId,
        );
        await _db.setSyncMeta(fullSyncKey, DateTime.now().toIso8601String());
      }

      return getWorkouts(isPublic: isPublic, authorId: authorId);
    } catch (e, stack) {
      // Offline-first: refresh failures fall back to the local cache. Report
      // to Sentry so silent own-scope sync failures are diagnosable.
      AppLog.warn('repo', 'Workout refresh failed, serving cache', e);
      Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setTag('subsystem', 'workout_repository');
          scope.setTag('repo.stage', 'refreshWorkouts');
          // The current user's id is already on every event via the global
          // SentryUser scope, so record only which scope failed, not the uid.
          scope.setContexts('refresh', {
            'is_public': ?isPublic,
            'own_scope': authorId != null,
          });
        },
      );
      return null;
    }
  }

  /// Reconciles the cache against the remote ID set for the current scope,
  /// in both directions:
  /// - **Purge**: cached in-scope workouts whose id is absent remotely (deleted).
  /// - **Backfill**: ids present remotely but missing locally (a workout the
  ///   incremental `updated_at` sync could never recover because it predates
  ///   `lastSynced`). Fetches the full rows and caches them.
  ///
  /// Workouts outside the current scope are untouched.
  Future<void> _reconcileScoped({
    required Set<String> remoteIds,
    bool? isPublic,
    String? authorId,
  }) async {
    final allCached = await _db.getAllCachedWorkouts();
    final cachedIds = <String>{};
    for (final row in allCached) {
      cachedIds.add(row.workoutId);
      if (remoteIds.contains(row.workoutId)) continue;
      final json = jsonDecode(row.workoutJson) as Map<String, dynamic>;
      final rowIsPublic = (json['is_public'] as bool?) ?? false;
      final rowAuthorId = (json['author_id'] as String?) ?? '';
      final inScope = (isPublic == null || rowIsPublic == isPublic) &&
          (authorId == null || rowAuthorId == authorId);
      if (inScope) {
        await _db.removeCachedWorkout(row.workoutId);
      }
    }

    // Backfill: ids present remotely but absent locally. Self-heals any device
    // where an in-scope workout was missed by a prior incremental sync.
    final missing =
        remoteIds.where((id) => !cachedIds.contains(id)).toList();
    if (missing.isNotEmpty) {
      // Scope-filter the response for symmetry with the purge half above. The
      // ids are already scoped (getWorkoutIds), so this only guards against a
      // remote ever returning out-of-scope rows into the wrong cache slot.
      final fetched = await _supabase.getWorkoutsByIds(missing);
      await _cacheWorkoutList(fetched
          .where((w) =>
              (isPublic == null || w.isPublic == isPublic) &&
              (authorId == null || w.authorId == authorId))
          .toList());
    }
  }

  /// Upserts [workouts] into the local cache as companion rows.
  Future<void> _cacheWorkoutList(List<Workout> workouts) {
    return _db.cacheWorkouts(
      workouts
          .map((w) => CachedWorkoutsCompanion.insert(
                workoutId: w.id,
                workoutJson: jsonEncode(w.toJson()),
                cachedAt: Value(DateTime.now()),
              ))
          .toList(),
    );
  }

  /// Whether the given scope has ever completed a sync (its synced-at metadata
  /// key is present). Distinguishes "own scope never synced" from "own scope
  /// synced but empty", which a cache-count check cannot.
  Future<bool> hasEverSynced({bool? isPublic, String? authorId}) async {
    final key = _syncedKey(isPublic: isPublic, authorId: authorId);
    return (await _db.getSyncMeta(key)) != null;
  }

  /// Returns the workout from cache if available; falls back to Supabase.
  /// Network result is cached for future offline access.
  Future<Workout> getWorkout(String id) async {
    final cached = await _db.getCachedWorkout(id);
    if (cached != null) {
      return Workout.fromJson(
        jsonDecode(cached.workoutJson) as Map<String, dynamic>,
      );
    }
    final workout = await _supabase.getWorkout(id);
    await _db.cacheWorkout(id, jsonEncode(workout.toJson()));
    return workout;
  }

  // ── Writes ───────────────────────────────────────────────────────────

  /// Saves to Supabase then updates the local cache.
  Future<Workout> saveWorkout(Workout workout) async {
    final saved = await _supabase.saveWorkout(workout);
    await _db.cacheWorkout(saved.id, jsonEncode(saved.toJson()));
    return saved;
  }

  /// Forks a workout on Supabase then caches the forked copy.
  Future<Workout> forkWorkout(String id) async {
    final forked = await _supabase.forkWorkout(id);
    await _db.cacheWorkout(forked.id, jsonEncode(forked.toJson()));
    return forked;
  }

  /// Deletes from Supabase then removes from cache.
  Future<void> deleteWorkout(String id) async {
    await _supabase.deleteWorkout(id);
    await _db.removeCachedWorkout(id);
  }
}

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(supabaseServiceProvider),
  );
});
