// Comprehensive SyncService tests.
//
// These tests require Drift code generation to have been run:
//   dart run build_runner build --delete-conflicting-outputs
//
// Without the generated local_db.g.dart, LocalDatabase and PendingResult
// types won't resolve. The model tests (test/models/*) work without codegen.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_result.dart';
import 'package:rowcraft/services/local_db.dart';
import 'package:rowcraft/services/sync_service.dart';
import 'package:rowcraft/services/supabase_service.dart';
import 'package:rowcraft/services/c2_logbook_service.dart';

// ---------------------------------------------------------------------------
// Mock LocalDatabase — in-memory implementation that tracks calls
// ---------------------------------------------------------------------------
class MockLocalDatabase implements LocalDatabase {
  final List<String> queuedJsons = [];
  List<PendingResult> pendingResults = [];
  final List<int> incrementedIds = [];
  final List<int> markedSupabaseIds = [];
  final List<int> markedC2Ids = [];
  int cleanupSyncedCalls = 0;

  @override
  Future<int> queueResult(String resultJson) async {
    queuedJsons.add(resultJson);
    return queuedJsons.length;
  }

  @override
  Future<List<PendingResult>> getPendingResults() async {
    return pendingResults;
  }

  @override
  Future<int> getPendingCount() async {
    return pendingResults.where((r) => !r.syncedToSupabase).length;
  }

  @override
  Future<void> markSyncedToSupabase(int id) async {
    markedSupabaseIds.add(id);
  }

  @override
  Future<void> markSyncedToC2(int id) async {
    markedC2Ids.add(id);
  }

  @override
  Future<void> incrementAttempts(int id) async {
    incrementedIds.add(id);
  }

  @override
  Future<int> cleanupSynced() async {
    cleanupSyncedCalls++;
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not mocked');
}

// ---------------------------------------------------------------------------
// Mock SupabaseService — returns the result it receives
// ---------------------------------------------------------------------------
class MockSupabaseService implements SupabaseService {
  bool shouldThrow = false;
  final List<WorkoutResult> savedResults = [];

  @override
  Future<WorkoutResult> saveResult(WorkoutResult result) async {
    if (shouldThrow) throw Exception('Supabase error');
    savedResults.add(result);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not mocked');
}

// ---------------------------------------------------------------------------
// Mock C2LogbookService — configurable linked state and sync outcome
// ---------------------------------------------------------------------------
class MockC2LogbookService implements C2LogbookService {
  bool linked = false;
  bool syncSuccess = true;
  final List<WorkoutResult> syncedResults = [];

  @override
  Future<bool> isLinked() async => linked;

  @override
  Future<bool> syncResult(WorkoutResult result) async {
    syncedResults.add(result);
    return syncSuccess;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not mocked');
}

// ---------------------------------------------------------------------------
// Fake PendingResult — Drift generates this DataClass; we replicate it here
// ---------------------------------------------------------------------------
class FakePendingResult implements PendingResult {
  @override
  final int id;
  @override
  final String resultJson;
  @override
  final DateTime queuedAt;
  @override
  final int attempts;
  @override
  final bool syncedToSupabase;
  @override
  final bool syncedToC2;

  FakePendingResult({
    required this.id,
    required this.resultJson,
    DateTime? queuedAt,
    this.attempts = 0,
    this.syncedToSupabase = false,
    this.syncedToC2 = false,
  }) : queuedAt = queuedAt ?? DateTime.now();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
WorkoutResult _makeResult({String id = 'result-001'}) {
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

PendingResult _fakePending({
  int id = 1,
  WorkoutResult? result,
  bool syncedToSupabase = false,
  bool syncedToC2 = false,
  int attempts = 0,
}) {
  final r = result ?? _makeResult();
  return FakePendingResult(
    id: id,
    resultJson: jsonEncode(r.toJson()),
    syncedToSupabase: syncedToSupabase,
    syncedToC2: syncedToC2,
    attempts: attempts,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late MockLocalDatabase mockDb;
  late MockSupabaseService mockSupabase;
  late MockC2LogbookService mockC2;
  late SyncService syncService;

  setUp(() {
    mockDb = MockLocalDatabase();
    mockSupabase = MockSupabaseService();
    mockC2 = MockC2LogbookService();
    syncService = SyncService(
      db: mockDb,
      supabaseService: mockSupabase,
      c2LogbookService: mockC2,
    );
  });

  group('queueResult', () {
    test('calls db.queueResult with JSON-encoded result', () async {
      mockDb.pendingResults = [];

      final result = _makeResult();
      await syncService.queueResult(result);

      expect(mockDb.queuedJsons, hasLength(1));

      final decoded =
          jsonDecode(mockDb.queuedJsons.first) as Map<String, dynamic>;
      expect(decoded['id'], result.id);
      expect(decoded['user_id'], result.userId);
      expect(decoded['total_distance'], result.totalDistance);
    });

    test('triggers immediate syncPendingResults after queuing', () async {
      // Put one pending result so we can observe the sync side-effect
      final result = _makeResult();
      mockDb.pendingResults = [_fakePending(id: 1, result: result)];
      mockC2.linked = false;

      await syncService.queueResult(result);

      // queueResult was called
      expect(mockDb.queuedJsons, hasLength(1));
      // And the pending result was synced via syncPendingResults
      expect(mockSupabase.savedResults, hasLength(1));
    });
  });

  group('syncPendingResults', () {
    test('processes all pending items to Supabase and marks them', () async {
      mockDb.pendingResults = [
        _fakePending(id: 1),
        _fakePending(id: 2, result: _makeResult(id: 'result-002')),
      ];
      mockC2.linked = false;

      await syncService.syncPendingResults();

      expect(mockSupabase.savedResults, hasLength(2));
      expect(mockDb.markedSupabaseIds, containsAll([1, 2]));
      expect(mockDb.markedC2Ids, containsAll([1, 2]));
      expect(mockDb.cleanupSyncedCalls, 1);
    });

    test('skips Supabase sync if already synced to Supabase', () async {
      mockDb.pendingResults = [
        _fakePending(id: 1, syncedToSupabase: true, syncedToC2: false),
      ];

      await syncService.syncPendingResults();

      expect(mockSupabase.savedResults, isEmpty);
      expect(mockDb.markedSupabaseIds, isEmpty);
    });

    test('C2 sync skipped when not linked', () async {
      mockDb.pendingResults = [_fakePending(id: 1)];
      mockC2.linked = false;

      await syncService.syncPendingResults();

      expect(mockC2.syncedResults, isEmpty);
      // Marked as synced so cleanup can proceed
      expect(mockDb.markedC2Ids, contains(1));
    });

    test('C2 sync performed and marked in DB when linked and successful',
        () async {
      mockDb.pendingResults = [_fakePending(id: 1)];
      mockC2.linked = true;
      mockC2.syncSuccess = true;

      await syncService.syncPendingResults();

      expect(mockC2.syncedResults, hasLength(1));
      // saveResult called twice: initial Supabase sync + update with syncedToC2
      expect(mockSupabase.savedResults, hasLength(2));
      expect(mockSupabase.savedResults.last.syncedToC2, true);
      expect(mockDb.markedC2Ids, contains(1));
    });

    test('C2 sync NOT marked when C2 sync returns false', () async {
      mockDb.pendingResults = [_fakePending(id: 1)];
      mockC2.linked = true;
      mockC2.syncSuccess = false;

      await syncService.syncPendingResults();

      expect(mockC2.syncedResults, hasLength(1));
      expect(mockSupabase.savedResults, hasLength(1));
      expect(mockDb.markedC2Ids, isEmpty);
    });

    test('failed sync increments attempt counter', () async {
      mockDb.pendingResults = [_fakePending(id: 1)];
      mockSupabase.shouldThrow = true;

      await syncService.syncPendingResults();

      expect(mockDb.incrementedIds, contains(1));
      expect(mockDb.markedSupabaseIds, isEmpty);
      expect(mockDb.markedC2Ids, isEmpty);
    });

    test('cleanup is called even when all syncs fail', () async {
      mockDb.pendingResults = [
        _fakePending(id: 1),
        _fakePending(id: 2),
      ];
      mockSupabase.shouldThrow = true;

      await syncService.syncPendingResults();

      expect(mockDb.incrementedIds, containsAll([1, 2]));
      expect(mockDb.cleanupSyncedCalls, 1);
    });

    test('handles empty pending list gracefully', () async {
      mockDb.pendingResults = [];

      await syncService.syncPendingResults();

      expect(mockSupabase.savedResults, isEmpty);
      expect(mockDb.cleanupSyncedCalls, 1);
    });
  });

  group('concurrent sync lock', () {
    test('second concurrent call returns immediately', () async {
      mockDb.pendingResults = [_fakePending(id: 1)];
      mockC2.linked = false;

      final first = syncService.syncPendingResults();
      final second = syncService.syncPendingResults();

      await Future.wait([first, second]);

      // Only one sync should have run
      expect(mockSupabase.savedResults, hasLength(1));
    });

    test('lock is released after sync completes, allowing next call',
        () async {
      mockDb.pendingResults = [_fakePending(id: 1)];
      mockC2.linked = false;

      await syncService.syncPendingResults();
      expect(mockSupabase.savedResults, hasLength(1));

      // Set up new pending results for second call
      mockDb.pendingResults = [
        _fakePending(id: 2, result: _makeResult(id: 'result-002')),
      ];

      await syncService.syncPendingResults();
      expect(mockSupabase.savedResults, hasLength(2));
    });

    test('lock is released even if sync throws', () async {
      mockDb.pendingResults = [_fakePending(id: 1)];
      mockSupabase.shouldThrow = true;

      await syncService.syncPendingResults();

      // Lock should be released — next call should work
      mockSupabase.shouldThrow = false;
      mockDb.pendingResults = [_fakePending(id: 2)];
      mockC2.linked = false;

      await syncService.syncPendingResults();
      expect(mockSupabase.savedResults, hasLength(1));
    });
  });

  group('pendingCount', () {
    test('delegates to db.getPendingCount', () async {
      mockDb.pendingResults = [
        _fakePending(id: 1, syncedToSupabase: false),
        _fakePending(id: 2, syncedToSupabase: false),
        _fakePending(id: 3, syncedToSupabase: true),
      ];

      final count = await syncService.pendingCount;
      expect(count, 2);
    });
  });
}
