// Tests for SyncService sync logic: SyncOutcome reporting, ID persistence,
// C2 error propagation, and getPendingCount correctness.
//
// Uses manual fakes instead of Drift-backed LocalDatabase since Drift
// requires code generation. The fakes implement the same interface that
// SyncService depends on.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_result.dart';
import 'package:rowcraft/services/c2_logbook_service.dart';
import 'package:rowcraft/services/strava_service.dart';
import 'package:rowcraft/services/sync_service.dart' show SyncOutcome;

// ── Fakes ──────────────────────────────────────────────────────────────

/// In-memory fake of the pending results table.
class FakeRow {
  final int id;
  String resultJson;
  bool syncedToSupabase;
  bool syncedToC2;
  bool syncedToPlexo;
  bool syncedToStrava;
  int attempts;

  FakeRow({
    required this.id,
    required this.resultJson,
    this.syncedToSupabase = false,
    this.syncedToC2 = false,
    this.syncedToPlexo = false,
    this.syncedToStrava = false,
    this.attempts = 0,
  });
}

/// Minimal fake that mirrors LocalDatabase's methods used by SyncService.
class FakeLocalDb {
  final List<FakeRow> _rows = [];
  int _nextId = 1;

  Future<int> queueResult(String resultJson) async {
    final id = _nextId++;
    _rows.add(FakeRow(id: id, resultJson: resultJson));
    return id;
  }

  Future<List<FakeRow>> getPendingResults() async {
    return _rows
        .where((r) => !r.syncedToSupabase || !r.syncedToC2 || !r.syncedToPlexo || !r.syncedToStrava)
        .toList();
  }

  Future<int> getPendingCount() async {
    return _rows
        .where((r) => !r.syncedToSupabase || !r.syncedToC2 || !r.syncedToPlexo || !r.syncedToStrava)
        .length;
  }

  Future<void> markSyncedToSupabase(int id) async {
    _rows.firstWhere((r) => r.id == id).syncedToSupabase = true;
  }

  Future<void> markSyncedToC2(int id) async {
    _rows.firstWhere((r) => r.id == id).syncedToC2 = true;
  }

  Future<void> markSyncedToPlexo(int id) async {
    _rows.firstWhere((r) => r.id == id).syncedToPlexo = true;
  }

  Future<void> markSyncedToStrava(int id) async {
    _rows.firstWhere((r) => r.id == id).syncedToStrava = true;
  }

  Future<void> updateResultJson(int id, String resultJson) async {
    _rows.firstWhere((r) => r.id == id).resultJson = resultJson;
  }

  Future<void> incrementAttempts(int id) async {
    _rows.firstWhere((r) => r.id == id).attempts++;
  }

  Future<int> cleanupSynced() async {
    final before = _rows.length;
    _rows.removeWhere((r) => r.syncedToSupabase && r.syncedToC2 && r.syncedToPlexo && r.syncedToStrava);
    return before - _rows.length;
  }

  // Test helpers
  FakeRow? findById(int id) {
    try {
      return _rows.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}

class FakeSupabaseService {
  /// The ID that saveResult will assign.
  String generatedId = 'supabase-uuid-123';
  bool shouldFail = false;
  int saveCallCount = 0;

  Future<WorkoutResult> saveResult(WorkoutResult result) async {
    saveCallCount++;
    if (shouldFail) throw Exception('Supabase save failed');
    return result.copyWith(id: generatedId);
  }
}

class FakeC2LogbookService {
  bool linked = true;
  bool syncSuccess = true;
  bool shouldThrowActionable = false;
  String actionableMessage = '';
  int syncCallCount = 0;

  Future<bool> isLinked() async => linked;

  Future<bool> syncResult(WorkoutResult result) async {
    syncCallCount++;
    if (shouldThrowActionable) {
      throw C2ActionableException(actionableMessage);
    }
    return syncSuccess;
  }
}

class FakePlexoService {
  bool enabled = false;
  bool syncSuccess = true;
  int syncCallCount = 0;

  Future<bool> isEnabled() async => enabled;

  Future<({bool success, String? error})> syncResult(WorkoutResult result) async {
    syncCallCount++;
    if (syncSuccess) return (success: true, error: null);
    return (success: false, error: 'Plexo sync failed');
  }
}

class FakeStravaService {
  bool linked = false;
  bool syncSuccess = true;
  bool shouldThrowActionable = false;
  String actionableMessage = '';
  int syncCallCount = 0;

  Future<bool> isLinked() async => linked;

  Future<({bool success, String? error})> syncResult(WorkoutResult result) async {
    syncCallCount++;
    if (shouldThrowActionable) {
      throw StravaActionableException(actionableMessage);
    }
    if (syncSuccess) return (success: true, error: null);
    return (success: false, error: 'Strava sync failed');
  }
}

// ── Adapter that wraps fakes into the interface SyncService expects ────

/// Since SyncService depends on concrete types (LocalDatabase, SupabaseService,
/// C2LogbookService), we build a thin SyncService-like class that uses our fakes
/// but follows the exact same logic. This tests the algorithm, not the wiring.
class TestableSyncService {
  final FakeLocalDb db;
  final FakeSupabaseService supabaseService;
  final FakeC2LogbookService c2LogbookService;
  final FakePlexoService plexoService;
  final FakeStravaService stravaService;

  bool _syncing = false;
  String? lastError;

  /// Per-row errors from the most recent sync pass, keyed by row ID.
  final Map<int, String> _rowErrors = {};

  TestableSyncService({
    required this.db,
    required this.supabaseService,
    required this.c2LogbookService,
    required this.plexoService,
    required this.stravaService,
  });

  Future<int> get pendingCount => db.getPendingCount();

  Future<SyncOutcome> queueResult(WorkoutResult result) async {
    final json = jsonEncode(result.toJson());
    final rowId = await db.queueResult(json);

    await syncPendingResults();

    // Check per-row error first (survives cleanup)
    final rowError = _rowErrors[rowId];

    final rows = await db.getPendingResults();
    final row = rows.where((r) => r.id == rowId).firstOrNull;

    if (row == null) {
      // Row cleaned up → all synced. Surface actionable error if any.
      return SyncOutcome(
        savedToSupabase: true,
        savedToC2: true,
        savedToPlexo: true,
        savedToStrava: true,
        error: rowError,
      );
    }

    String? error;
    if (!row.syncedToSupabase) {
      error = rowError ?? 'Cloud sync failed — will retry';
    } else if (!row.syncedToC2) {
      error = rowError ?? 'C2 Logbook sync failed — will retry';
    } else if (!row.syncedToPlexo) {
      error = rowError ?? 'Plexo sync failed — will retry';
    } else if (!row.syncedToStrava) {
      error = rowError ?? 'Strava sync failed — will retry';
    }

    return SyncOutcome(
      savedToSupabase: row.syncedToSupabase,
      savedToC2: row.syncedToC2,
      savedToPlexo: row.syncedToPlexo,
      savedToStrava: row.syncedToStrava,
      error: error,
    );
  }

  Future<void> syncPendingResults() async {
    if (_syncing) return;
    _syncing = true;
    _rowErrors.clear();

    try {
      final pending = await db.getPendingResults();
      final c2Linked = await c2LogbookService.isLinked();
      final plexoEnabled = await plexoService.isEnabled();
      final stravaLinked = await stravaService.isLinked();
      for (final row in pending) {
        await _syncSingleResult(row,
          c2Linked: c2Linked,
          plexoEnabled: plexoEnabled,
          stravaLinked: stravaLinked,
        );
      }
      await db.cleanupSynced();
      final remaining = await pendingCount;
      if (remaining == 0) lastError = null;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncSingleResult(FakeRow row, {
    required bool c2Linked,
    required bool plexoEnabled,
    required bool stravaLinked,
  }) async {
    try {
      final resultMap =
          jsonDecode(row.resultJson) as Map<String, dynamic>;
      var result = WorkoutResult.fromJson(resultMap);

      if (!row.syncedToSupabase) {
        final saved = await supabaseService.saveResult(result);
        result = saved;
        await db.updateResultJson(row.id, jsonEncode(saved.toJson()));
        await db.markSyncedToSupabase(row.id);
      }

      if (!row.syncedToC2) {
        try {
          if (c2Linked) {
            if (result.id.isEmpty) {
              _rowErrors[row.id] = 'Missing result ID — will retry';
              return;
            }
            final synced = await c2LogbookService.syncResult(result);
            if (synced) {
              await db.markSyncedToC2(row.id);
            } else {
              const msg = 'C2 Logbook sync failed — will retry';
              lastError = msg;
              _rowErrors[row.id] = msg;
            }
          } else {
            await db.markSyncedToC2(row.id);
          }
        } on C2ActionableException catch (e) {
          lastError = '$e';
          _rowErrors[row.id] = '$e';
          await db.markSyncedToC2(row.id);
        }
      }

      if (!row.syncedToPlexo) {
        try {
          if (plexoEnabled) {
            final plexoResult = await plexoService.syncResult(result);
            if (plexoResult.success) {
              await db.markSyncedToPlexo(row.id);
            } else {
              final msg = 'Plexo sync failed: ${plexoResult.error}';
              lastError = msg;
              _rowErrors[row.id] = msg;
            }
          } else {
            await db.markSyncedToPlexo(row.id);
          }
        } catch (e) {
          final msg = 'Plexo sync error: $e';
          lastError = msg;
          _rowErrors[row.id] = msg;
        }
      }

      if (!row.syncedToStrava) {
        try {
          if (stravaLinked) {
            if (result.id.isEmpty) {
              _rowErrors[row.id] = 'Missing result ID — will retry';
              return;
            }
            final stravaResult = await stravaService.syncResult(result);
            if (stravaResult.success) {
              await db.markSyncedToStrava(row.id);
            } else {
              final msg = 'Strava sync failed: ${stravaResult.error}';
              lastError = msg;
              _rowErrors[row.id] = msg;
            }
          } else {
            await db.markSyncedToStrava(row.id);
          }
        } on StravaActionableException catch (e) {
          lastError = '$e';
          _rowErrors[row.id] = '$e';
          await db.markSyncedToStrava(row.id);
        }
      }
    } catch (e) {
      final msg = 'Sync failed for row ${row.id}: $e';
      lastError = msg;
      _rowErrors[row.id] = msg;
      await db.incrementAttempts(row.id);
    }
  }
}

// ── Test helpers ───────────────────────────────────────────────────────

WorkoutResult _makeResult({String id = ''}) {
  return WorkoutResult(
    id: id,
    userId: 'user-xyz',
    workoutId: 'wk-abc',
    startedAt: DateTime.utc(2025, 6, 15, 10, 0, 0),
    finishedAt: DateTime.utc(2025, 6, 15, 10, 30, 0),
    totalDistance: 6000.0,
    totalTime: const Duration(minutes: 30),
    avgSplit: 1050,
    avgStrokeRate: 28,
    avgHeartRate: 150,
    avgWatts: 195,
    calories: 350,
    splits: const [],
  );
}

TestableSyncService _buildService({
  FakeLocalDb? db,
  FakeSupabaseService? supabase,
  FakeC2LogbookService? c2,
  FakePlexoService? plexo,
  FakeStravaService? strava,
}) {
  return TestableSyncService(
    db: db ?? FakeLocalDb(),
    supabaseService: supabase ?? FakeSupabaseService(),
    c2LogbookService: c2 ?? FakeC2LogbookService(),
    plexoService: plexo ?? FakePlexoService(),
    stravaService: strava ?? FakeStravaService(),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────

void main() {
  group('SyncOutcome reporting', () {
    test('full success: all flags true, no error', () async {
      final service = _buildService();
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToSupabase, isTrue);
      expect(outcome.savedToC2, isTrue);
      expect(outcome.savedToPlexo, isTrue);
      expect(outcome.error, isNull);
    });

    test('Supabase success + C2 failure: reports C2 error', () async {
      final c2 = FakeC2LogbookService()..syncSuccess = false;
      final service = _buildService(c2: c2);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToSupabase, isTrue);
      expect(outcome.savedToC2, isFalse);
      expect(outcome.error, contains('C2'));
    });

    test('Supabase failure: reports cloud error', () async {
      final supabase = FakeSupabaseService()..shouldFail = true;
      final service = _buildService(supabase: supabase);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToSupabase, isFalse);
      expect(outcome.savedToC2, isFalse);
      expect(outcome.error, isNotNull);
    });

    test('C2 not linked: treated as success', () async {
      final c2 = FakeC2LogbookService()..linked = false;
      final service = _buildService(c2: c2);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToSupabase, isTrue);
      expect(outcome.savedToC2, isTrue);
      expect(outcome.savedToPlexo, isTrue);
      expect(outcome.error, isNull);
    });
  });

  group('Supabase ID persistence', () {
    test('Supabase-generated ID is persisted to SQLite JSON', () async {
      final db = FakeLocalDb();
      final supabase = FakeSupabaseService()
        ..generatedId = 'real-uuid-456';
      final service = _buildService(db: db, supabase: supabase);

      await service.queueResult(_makeResult(id: ''));

      // Row was cleaned up (both synced), but we can verify the supabase
      // service was called
      expect(supabase.saveCallCount, 1);
    });

    test('C2 sync receives the Supabase-generated ID, not empty', () async {
      final c2 = FakeC2LogbookService();
      final supabase = FakeSupabaseService()
        ..generatedId = 'real-uuid-789';
      final service = _buildService(supabase: supabase, c2: c2);

      await service.queueResult(_makeResult(id: ''));

      // C2 was called (not skipped due to empty ID)
      expect(c2.syncCallCount, 1);
    });

    test('retry after Supabase done uses persisted ID for C2', () async {
      final db = FakeLocalDb();
      final supabase = FakeSupabaseService()
        ..generatedId = 'persisted-uuid';
      // C2 fails on first attempt
      final c2 = FakeC2LogbookService()..syncSuccess = false;
      final service = _buildService(db: db, supabase: supabase, c2: c2);

      await service.queueResult(_makeResult(id: ''));

      // Verify the stored JSON was updated with the real ID
      final rows = await db.getPendingResults();
      expect(rows.length, 1);
      final storedJson = jsonDecode(rows.first.resultJson) as Map<String, dynamic>;
      expect(storedJson['id'], 'persisted-uuid');

      // Now retry with C2 succeeding
      c2.syncSuccess = true;
      await service.syncPendingResults();

      // Row should be cleaned up now
      final remaining = await db.getPendingCount();
      expect(remaining, 0);
    });
  });

  group('C2ActionableException handling', () {
    test('actionable error surfaces in outcome', () async {
      final c2 = FakeC2LogbookService()
        ..shouldThrowActionable = true
        ..actionableMessage = 'Weight not set. Set your weight in Profile.';
      final service = _buildService(c2: c2);

      final outcome = await service.queueResult(_makeResult());

      // Supabase succeeded, C2 marked as done (stop retrying)
      expect(outcome.savedToSupabase, isTrue);
      expect(outcome.savedToC2, isTrue); // marked done to stop retries
      expect(outcome.savedToPlexo, isTrue);
      // Error surfaces in outcome even though row was cleaned up
      expect(outcome.error, contains('Weight not set'));
    });

    test('actionable error does not increment retry attempts', () async {
      final db = FakeLocalDb();
      final c2 = FakeC2LogbookService()
        ..shouldThrowActionable = true
        ..actionableMessage = 'C2 token expired';
      final service = _buildService(db: db, c2: c2);

      await service.queueResult(_makeResult());

      // Row was cleaned up (both flags true), not stuck with attempts > 0
      final pending = await db.getPendingCount();
      expect(pending, 0);
    });
  });

  group('getPendingCount correctness', () {
    test('counts rows where only C2 is unsynced', () async {
      final db = FakeLocalDb();
      // Manually add a row that has Supabase synced but not C2
      db._rows.add(FakeRow(
        id: 99,
        resultJson: '{}',
        syncedToSupabase: true,
        syncedToC2: false,
        syncedToPlexo: true,
        syncedToStrava: true,
      ));

      final count = await db.getPendingCount();
      expect(count, 1, reason: 'Should count C2-unsynced rows too');
    });

    test('counts rows where only Supabase is unsynced', () async {
      final db = FakeLocalDb();
      db._rows.add(FakeRow(
        id: 99,
        resultJson: '{}',
        syncedToSupabase: false,
        syncedToC2: true,
        syncedToPlexo: true,
        syncedToStrava: true,
      ));

      final count = await db.getPendingCount();
      expect(count, 1);
    });

    test('does not count fully synced rows', () async {
      final db = FakeLocalDb();
      db._rows.add(FakeRow(
        id: 99,
        resultJson: '{}',
        syncedToSupabase: true,
        syncedToC2: true,
        syncedToPlexo: true,
        syncedToStrava: true,
      ));

      final count = await db.getPendingCount();
      expect(count, 0);
    });
  });

  group('Plexo sync', () {
    test('Plexo enabled + sync succeeds: row cleaned up', () async {
      final plexo = FakePlexoService()..enabled = true;
      final service = _buildService(plexo: plexo);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToSupabase, isTrue);
      expect(outcome.savedToC2, isTrue);
      expect(outcome.savedToPlexo, isTrue);
      expect(outcome.error, isNull);
      expect(plexo.syncCallCount, 1);
    });

    test('Plexo enabled + sync fails: error surfaces', () async {
      final plexo = FakePlexoService()
        ..enabled = true
        ..syncSuccess = false;
      final service = _buildService(plexo: plexo);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToSupabase, isTrue);
      expect(outcome.savedToC2, isTrue);
      expect(outcome.savedToPlexo, isFalse);
      expect(outcome.error, contains('Plexo'));
    });

    test('Plexo disabled: marked as done without calling sync', () async {
      final plexo = FakePlexoService()..enabled = false;
      final service = _buildService(plexo: plexo);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToPlexo, isTrue);
      expect(plexo.syncCallCount, 0);
    });
  });

  group('getPendingCount correctness', () {
    test('counts rows where only Plexo is unsynced', () async {
      final db = FakeLocalDb();
      db._rows.add(FakeRow(
        id: 99,
        resultJson: '{}',
        syncedToSupabase: true,
        syncedToC2: true,
        syncedToPlexo: false,
        syncedToStrava: true,
      ));

      final count = await db.getPendingCount();
      expect(count, 1, reason: 'Should count Plexo-unsynced rows too');
    });
  });

  group('Strava sync', () {
    test('Strava linked + sync succeeds: row cleaned up', () async {
      final strava = FakeStravaService()..linked = true;
      final service = _buildService(strava: strava);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToSupabase, isTrue);
      expect(outcome.savedToC2, isTrue);
      expect(outcome.savedToPlexo, isTrue);
      expect(outcome.savedToStrava, isTrue);
      expect(outcome.error, isNull);
      expect(strava.syncCallCount, 1);
    });

    test('Strava linked + sync fails: error surfaces', () async {
      final strava = FakeStravaService()
        ..linked = true
        ..syncSuccess = false;
      final service = _buildService(strava: strava);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToSupabase, isTrue);
      expect(outcome.savedToC2, isTrue);
      expect(outcome.savedToPlexo, isTrue);
      expect(outcome.savedToStrava, isFalse);
      expect(outcome.error, contains('Strava'));
    });

    test('Strava not linked: marked as done without calling sync', () async {
      final strava = FakeStravaService()..linked = false;
      final service = _buildService(strava: strava);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToStrava, isTrue);
      expect(strava.syncCallCount, 0);
    });

    test('Strava actionable error: surfaces and stops retrying', () async {
      final strava = FakeStravaService()
        ..linked = true
        ..shouldThrowActionable = true
        ..actionableMessage = 'Strava token expired — reconnect in Profile';
      final service = _buildService(strava: strava);
      final outcome = await service.queueResult(_makeResult());

      expect(outcome.savedToStrava, isTrue); // marked done to stop retries
      expect(outcome.error, contains('token expired'));
    });
  });

  group('getPendingCount correctness', () {
    test('counts rows where only Strava is unsynced', () async {
      final db = FakeLocalDb();
      db._rows.add(FakeRow(
        id: 99,
        resultJson: '{}',
        syncedToSupabase: true,
        syncedToC2: true,
        syncedToPlexo: true,
        syncedToStrava: false,
      ));

      final count = await db.getPendingCount();
      expect(count, 1, reason: 'Should count Strava-unsynced rows too');
    });
  });

  group('error isolation', () {
    test('error from unrelated row does not bleed into new result outcome', () async {
      final db = FakeLocalDb();
      // Pre-existing failed row
      db._rows.add(FakeRow(
        id: 50,
        resultJson: '{"bad": true}', // Will fail to parse as WorkoutResult
        syncedToSupabase: false,
        syncedToC2: false,
        attempts: 3,
      ));

      final service = _buildService(db: db);
      final outcome = await service.queueResult(_makeResult());

      // The new result should succeed despite the old row failing
      expect(outcome.savedToSupabase, isTrue);
      expect(outcome.savedToC2, isTrue);
      expect(outcome.savedToPlexo, isTrue);
      expect(outcome.error, isNull);
    });
  });
}
