import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_result.dart';
import 'local_db.dart';
import 'supabase_service.dart';
import 'c2_logbook_service.dart';
import 'plexo_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(localDatabaseProvider),
    supabaseService: ref.watch(supabaseServiceProvider),
    c2LogbookService: ref.watch(c2LogbookServiceProvider),
    plexoService: ref.watch(plexoServiceProvider),
  );
});

/// Result of a sync attempt for a single queued result.
class SyncOutcome {
  final bool savedToSupabase;
  final bool savedToC2;
  final bool savedToPlexo;
  final String? error;

  /// The Supabase-generated result ID, if the save succeeded.
  final String? resultId;

  const SyncOutcome({
    required this.savedToSupabase,
    required this.savedToC2,
    required this.savedToPlexo,
    this.error,
    this.resultId,
  });
}

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
  final PlexoService plexoService;

  bool _syncing = false;

  /// Last sync error message, if any. Cleared on successful sync.
  String? lastError;

  /// Per-row errors from the most recent sync pass, keyed by SQLite row ID.
  final Map<int, String> _rowErrors = {};

  /// Per-row Supabase result IDs from the most recent sync pass.
  final Map<int, String> _rowResultIds = {};

  SyncService({
    required this.db,
    required this.supabaseService,
    required this.c2LogbookService,
    required this.plexoService,
  });

  /// Number of results waiting to be synced.
  Future<int> get pendingCount => db.getPendingCount();

  /// Queue a workout result for syncing.
  ///
  /// The result is immediately persisted to SQLite, so it survives
  /// app restarts. Then an immediate sync attempt is made.
  /// Returns a [SyncOutcome] indicating what was synced.
  Future<SyncOutcome> queueResult(WorkoutResult result) async {
    final json = jsonEncode(result.toJson());
    final rowId = await db.queueResult(json);

    // Clear stale per-row errors before this sync attempt.
    // Prevents a prior pass's errors from bleeding in if syncPendingResults
    // bails early on the _syncing guard.
    _rowErrors.clear();
    _rowResultIds.clear();

    // Attempt immediate sync
    await syncPendingResults();

    // Check per-row results (survive cleanup)
    final rowError = _rowErrors[rowId];
    final resultId = _rowResultIds[rowId];

    // Query this specific row to report what actually synced.
    // If absent, both synced and it was cleaned up.
    final rows = await db.getPendingResults();
    final row = rows.where((r) => r.id == rowId).firstOrNull;

    if (row == null) {
      // Row cleaned up → all synced. Surface actionable error if any.
      return SyncOutcome(
        savedToSupabase: true,
        savedToC2: true,
        savedToPlexo: true,
        error: rowError,
        resultId: resultId,
      );
    }

    String? error;
    if (!row.syncedToSupabase) {
      error = rowError ?? 'Cloud sync failed — will retry';
    } else if (!row.syncedToC2) {
      error = rowError ?? 'C2 Logbook sync failed — will retry';
    } else if (!row.syncedToPlexo) {
      error = rowError ?? 'Plexo sync failed — will retry';
    }

    return SyncOutcome(
      savedToSupabase: row.syncedToSupabase,
      savedToC2: row.syncedToC2,
      savedToPlexo: row.syncedToPlexo,
      error: error,
      resultId: resultId,
    );
  }

  /// Retry syncing pending results without re-queuing.
  /// Returns a [SyncOutcome] reflecting the current sync status.
  Future<SyncOutcome> retrySync() async {
    _rowErrors.clear();
    _rowResultIds.clear();

    await syncPendingResults();

    final pending = await db.getPendingResults();
    if (pending.isEmpty) {
      return const SyncOutcome(
        savedToSupabase: true,
        savedToC2: true,
        savedToPlexo: true,
      );
    }

    final row = pending.last;
    final error = _rowErrors[row.id];
    final resultId = _rowResultIds[row.id];

    return SyncOutcome(
      savedToSupabase: row.syncedToSupabase,
      savedToC2: row.syncedToC2,
      savedToPlexo: row.syncedToPlexo,
      error: error,
      resultId: resultId,
    );
  }

  /// Attempt to sync all pending results to Supabase and C2 Logbook.
  ///
  /// This is safe to call multiple times — it uses a lock to prevent
  /// concurrent sync attempts. Failed results remain in the database
  /// with an incremented attempt counter.
  Future<void> syncPendingResults() async {
    if (_syncing) return;
    _syncing = true;
    _rowErrors.clear();
    _rowResultIds.clear();

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
        final saved = await supabaseService.saveResult(result);
        result = saved;
        if (saved.id.isNotEmpty) _rowResultIds[row.id] = saved.id;
        // Persist the real ID to SQLite so retries use it for C2 sync
        await db.updateResultJson(row.id, jsonEncode(saved.toJson()));
        await db.markSyncedToSupabase(row.id);
      } else if (result.id.isNotEmpty) {
        // Retry path — ID already persisted from prior Supabase save
        _rowResultIds[row.id] = result.id;
      }

      // Step 2: Sync to C2 Logbook if linked and not yet done
      if (!row.syncedToC2) {
        try {
          final isLinked = await c2LogbookService.isLinked();
          if (isLinked) {
            if (result.id.isEmpty) {
              const msg = 'Missing result ID — will retry';
              _rowErrors[row.id] = msg;
              return;
            }
            final c2Result = await c2LogbookService.syncResult(result);
            if (c2Result.success) {
              await db.markSyncedToC2(row.id);
            } else {
              final msg = 'C2 sync failed: ${c2Result.error}';
              lastError = msg;
              _rowErrors[row.id] = msg;
              debugPrint(msg);
            }
          } else {
            // Not linked to C2 — mark as "synced" so it gets cleaned up
            await db.markSyncedToC2(row.id);
          }
        } on C2ActionableException catch (e) {
          // User-fixable error (e.g. weight not set) — surface message,
          // mark C2 as done to stop retrying.
          lastError = '$e';
          _rowErrors[row.id] = '$e';
          debugPrint('C2 actionable error for row ${row.id}: $e');
          await db.markSyncedToC2(row.id);
        }
      }

      // Step 3: Sync to Plexo if enabled and not yet done
      if (!row.syncedToPlexo) {
        try {
          final isEnabled = await plexoService.isEnabled();
          if (isEnabled) {
            final plexoResult = await plexoService.syncResult(result);
            if (plexoResult.success) {
              await db.markSyncedToPlexo(row.id);
            } else {
              final msg = 'Plexo sync failed: ${plexoResult.error}';
              lastError = msg;
              _rowErrors[row.id] = msg;
              debugPrint(msg);
            }
          } else {
            // Not enabled — mark as done so cleanup proceeds
            await db.markSyncedToPlexo(row.id);
          }
        } catch (e) {
          final msg = 'Plexo sync error: $e';
          lastError = msg;
          _rowErrors[row.id] = msg;
          debugPrint(msg);
        }
      }
    } catch (e) {
      final msg = 'Sync failed for row ${row.id}: $e';
      lastError = msg;
      _rowErrors[row.id] = msg;
      debugPrint(msg);
      await db.incrementAttempts(row.id);
    }
  }
}
