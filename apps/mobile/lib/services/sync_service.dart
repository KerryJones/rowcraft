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

  /// Last sync error message, if any. Cleared on successful sync.
  String? lastError;

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

      // Clear error if everything synced
      final remaining = await pendingCount;
      if (remaining == 0) lastError = null;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncSingleResult(PendingResult row) async {
    try {
      final resultMap =
          jsonDecode(row.resultJson) as Map<String, dynamic>;
      var result = WorkoutResult.fromJson(resultMap);

      // Step 1: Sync to Supabase if not yet done
      if (!row.syncedToSupabase) {
        // saveResult returns the persisted result with a Supabase-generated ID
        result = await supabaseService.saveResult(result);
        await db.markSyncedToSupabase(row.id);
      }

      // Step 2: Sync to C2 Logbook if linked and not yet done
      if (!row.syncedToC2) {
        final isLinked = await c2LogbookService.isLinked();
        if (isLinked) {
          if (result.id.isEmpty) {
            // Need the Supabase ID for C2 sync — re-fetch isn't needed
            // because step 1 always runs first and returns the ID.
            // If we somehow got here with no ID, skip C2 this cycle.
            return;
          }
          final c2Result = await c2LogbookService.syncResult(result);
          if (c2Result.success) {
            await db.markSyncedToC2(row.id);
          } else {
            lastError = 'C2 sync failed: ${c2Result.error}';
            debugPrint(lastError);
          }
        } else {
          // Not linked to C2 — mark as "synced" so it gets cleaned up
          await db.markSyncedToC2(row.id);
        }
      }
    } on C2ActionableException catch (e) {
      // User-fixable error (e.g. weight not set) — surface message,
      // mark C2 as done to stop retrying (Supabase sync is already complete).
      lastError = '$e';
      debugPrint('C2 actionable error for row ${row.id}: $e');
      await db.markSyncedToC2(row.id);
    } catch (e) {
      lastError = 'Sync failed for row ${row.id}: $e';
      debugPrint(lastError);
      await db.incrementAttempts(row.id);
    }
  }
}
