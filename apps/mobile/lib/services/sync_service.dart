import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_result.dart';
import 'local_db.dart';
import 'supabase_service.dart';
import 'c2_logbook_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(localDatabaseProvider),
    supabaseService: ref.watch(supabaseServiceProvider),
    c2LogbookService: ref.watch(c2LogbookServiceProvider),
  );
});

/// Offline-first sync service backed by SQLite via Drift.
///
/// Workout results are persisted to a local database immediately
/// on completion, then synced to Supabase (and optionally C2 Logbook)
/// when connectivity is available. Results survive app restarts,
/// crashes, and airplane mode.
class SyncService {
  final LocalDatabase db;
  final SupabaseService supabaseService;
  final C2LogbookService c2LogbookService;

  bool _syncing = false;

  SyncService({
    required this.db,
    required this.supabaseService,
    required this.c2LogbookService,
  });

  /// Number of results waiting to be synced.
  Future<int> get pendingCount => db.getPendingCount();

  /// Queue a workout result for syncing.
  ///
  /// The result is immediately persisted to SQLite, so it survives
  /// app restarts. Then an immediate sync attempt is made.
  Future<void> queueResult(WorkoutResult result) async {
    final json = jsonEncode(result.toJson());
    await db.queueResult(json);

    // Attempt immediate sync
    await syncPendingResults();
  }

  /// Attempt to sync all pending results to Supabase and C2 Logbook.
  ///
  /// This is safe to call multiple times — it uses a lock to prevent
  /// concurrent sync attempts. Failed results remain in the database
  /// with an incremented attempt counter.
  Future<void> syncPendingResults() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final pending = await db.getPendingResults();

      for (final row in pending) {
        await _syncSingleResult(row);
      }

      // Clean up fully synced results
      await db.cleanupSynced();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncSingleResult(PendingResult row) async {
    try {
      final resultMap =
          jsonDecode(row.resultJson) as Map<String, dynamic>;
      final result = WorkoutResult.fromJson(resultMap);

      // Step 1: Sync to Supabase if not yet done
      if (!row.syncedToSupabase) {
        await supabaseService.saveResult(result);
        await db.markSyncedToSupabase(row.id);
      }

      // Step 2: Sync to C2 Logbook if linked and not yet done
      if (!row.syncedToC2) {
        final isLinked = await c2LogbookService.isLinked();
        if (isLinked) {
          // The edge function handles the C2 API call and sets
          // synced_to_c2=true in the DB — no need for a second upsert
          final synced = await c2LogbookService.syncResult(result);
          if (synced) {
            await db.markSyncedToC2(row.id);
          }
        } else {
          // Not linked to C2 — mark as "synced" so it gets cleaned up
          await db.markSyncedToC2(row.id);
        }
      }
    } catch (e) {
      // Failed — increment attempt counter, will retry next time
      assert(() { debugPrint('Sync failed for row ${row.id}: $e'); return true; }());
      await db.incrementAttempts(row.id);
    }
  }
}
