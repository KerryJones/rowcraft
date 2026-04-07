// Tests for WorkoutRepository caching logic: cache-first reads, incremental sync,
// scoped delete detection, offline fallback, minInterval throttle, and
// write-through on save/delete.
//
// Uses manual fakes instead of Drift-backed LocalDatabase since Drift requires
// code generation. The TestableWorkoutRepository mirrors the exact algorithm
// that WorkoutRepository will use.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout.dart';
import 'package:rowcraft/models/workout_segment.dart';

// ── Fakes ──────────────────────────────────────────────────────────────

/// In-memory fake of the CachedWorkouts table + SyncMetadata table.
class FakeCacheDb {
  final Map<String, String> _cache = {}; // workoutId → workoutJson
  final Map<String, String> _meta = {}; // key → value

  Future<List<FakeCachedRow>> getAllCachedWorkouts() async =>
      _cache.entries.map((e) => FakeCachedRow(e.key, e.value)).toList();

  Future<String?> getCachedWorkout(String id) async => _cache[id];

  Future<void> cacheWorkouts(List<Workout> workouts) async {
    for (final w in workouts) {
      _cache[w.id] = jsonEncode(w.toJson());
    }
  }

  Future<void> cacheWorkout(String id, String json) async {
    _cache[id] = json;
  }

  Future<void> removeCachedWorkout(String id) async {
    _cache.remove(id);
  }

  Future<String?> getSyncMeta(String key) async => _meta[key];

  Future<void> setSyncMeta(String key, String value) async {
    _meta[key] = value;
  }

  // Test helpers
  bool hasCached(String id) => _cache.containsKey(id);
  int get cachedCount => _cache.length;
  String? getMeta(String key) => _meta[key];
}

class FakeCachedRow {
  final String workoutId;
  final String workoutJson;
  FakeCachedRow(this.workoutId, this.workoutJson);
}

/// In-memory fake of the SupabaseService workout methods.
class FakeWorkoutService {
  final List<Workout> _workouts;
  bool shouldThrow = false;
  int getWorkoutsCallCount = 0;
  int getWorkoutsUpdatedSinceCallCount = 0;
  int getWorkoutIdsCallCount = 0;
  int getWorkoutCallCount = 0;
  int saveCallCount = 0;
  int deleteCallCount = 0;

  FakeWorkoutService(List<Workout> workouts) : _workouts = List.of(workouts);

  Future<List<Workout>> getWorkouts({bool? isPublic, String? authorId}) async {
    getWorkoutsCallCount++;
    if (shouldThrow) throw Exception('Network error');
    var result = _workouts.toList();
    if (isPublic != null) result = result.where((w) => w.isPublic == isPublic).toList();
    if (authorId != null) result = result.where((w) => w.authorId == authorId).toList();
    return result;
  }

  Future<List<Workout>> getWorkoutsUpdatedSince(DateTime since,
      {bool? isPublic, String? authorId}) async {
    getWorkoutsUpdatedSinceCallCount++;
    if (shouldThrow) throw Exception('Network error');
    var result = _workouts.where((w) => w.updatedAt.isAfter(since)).toList();
    if (isPublic != null) result = result.where((w) => w.isPublic == isPublic).toList();
    if (authorId != null) result = result.where((w) => w.authorId == authorId).toList();
    return result;
  }

  Future<List<String>> getWorkoutIds({bool? isPublic, String? authorId}) async {
    getWorkoutIdsCallCount++;
    if (shouldThrow) throw Exception('Network error');
    var result = _workouts.toList();
    if (isPublic != null) result = result.where((w) => w.isPublic == isPublic).toList();
    if (authorId != null) result = result.where((w) => w.authorId == authorId).toList();
    return result.map((w) => w.id).toList();
  }

  Future<Workout> getWorkout(String id) async {
    getWorkoutCallCount++;
    if (shouldThrow) throw Exception('Network error');
    return _workouts.firstWhere((w) => w.id == id);
  }

  Future<Workout> saveWorkout(Workout workout) async {
    saveCallCount++;
    if (shouldThrow) throw Exception('Network error');
    final idx = _workouts.indexWhere((w) => w.id == workout.id);
    if (idx >= 0) {
      _workouts[idx] = workout;
    } else {
      _workouts.add(workout);
    }
    return workout;
  }

  Future<Workout> forkWorkout(String originalId, String newId) async {
    if (shouldThrow) throw Exception('Network error');
    final original = _workouts.firstWhere((w) => w.id == originalId);
    final forked = original.copyWith(id: newId, title: '${original.title} (fork)');
    _workouts.add(forked);
    return forked;
  }

  Future<void> deleteWorkout(String id) async {
    deleteCallCount++;
    if (shouldThrow) throw Exception('Network error');
    _workouts.removeWhere((w) => w.id == id);
  }
}

// ── Testable repository ─────────────────────────────────────────────────
//
// Same logic as WorkoutRepository, using fakes instead of real services.

const _fullSyncMaxAge = Duration(hours: 24);

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

class TestableWorkoutRepository {
  final FakeCacheDb db;
  final FakeWorkoutService service;

  TestableWorkoutRepository({required this.db, required this.service});

  Future<List<Workout>> getWorkouts({bool? isPublic, String? authorId}) async {
    final rows = await db.getAllCachedWorkouts();
    final workouts = rows
        .map((r) => Workout.fromJson(jsonDecode(r.workoutJson) as Map<String, dynamic>))
        .toList();
    var result = workouts;
    if (isPublic != null) result = result.where((w) => w.isPublic == isPublic).toList();
    if (authorId != null) result = result.where((w) => w.authorId == authorId).toList();
    return result;
  }

  Future<List<Workout>?> refreshWorkouts({
    bool? isPublic,
    String? authorId,
    Duration minInterval = Duration.zero,
  }) async {
    final syncedKey = _syncedKey(isPublic: isPublic, authorId: authorId);
    final fullSyncKey_ = _fullSyncKey(isPublic: isPublic, authorId: authorId);

    final lastSyncedStr = await db.getSyncMeta(syncedKey);
    final lastFullSyncStr = await db.getSyncMeta(fullSyncKey_);

    if (minInterval > Duration.zero && lastSyncedStr != null) {
      final age = DateTime.now().difference(DateTime.parse(lastSyncedStr));
      if (age < minInterval) return null;
    }

    final needsFullSync = lastFullSyncStr == null ||
        DateTime.now().difference(DateTime.parse(lastFullSyncStr)) > _fullSyncMaxAge;

    try {
      List<Workout> fetched;
      if (lastSyncedStr == null) {
        fetched = await service.getWorkouts(isPublic: isPublic, authorId: authorId);
      } else {
        fetched = await service.getWorkoutsUpdatedSince(
          DateTime.parse(lastSyncedStr),
          isPublic: isPublic,
          authorId: authorId,
        );
      }

      await db.cacheWorkouts(fetched);
      await db.setSyncMeta(syncedKey, DateTime.now().toIso8601String());

      if (needsFullSync) {
        final remoteIds =
            (await service.getWorkoutIds(isPublic: isPublic, authorId: authorId)).toSet();
        await _removeScopedDeleted(remoteIds: remoteIds, isPublic: isPublic, authorId: authorId);
        await db.setSyncMeta(fullSyncKey_, DateTime.now().toIso8601String());
      }

      return getWorkouts(isPublic: isPublic, authorId: authorId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeScopedDeleted({
    required Set<String> remoteIds,
    bool? isPublic,
    String? authorId,
  }) async {
    final allCached = await db.getAllCachedWorkouts();
    for (final row in allCached) {
      if (remoteIds.contains(row.workoutId)) continue;
      final json = jsonDecode(row.workoutJson) as Map<String, dynamic>;
      final rowIsPublic = (json['is_public'] as bool?) ?? false;
      final rowAuthorId = (json['author_id'] as String?) ?? '';
      final inScope = (isPublic == null || rowIsPublic == isPublic) &&
          (authorId == null || rowAuthorId == authorId);
      if (inScope) {
        await db.removeCachedWorkout(row.workoutId);
      }
    }
  }

  Future<Workout> getWorkout(String id) async {
    final cached = await db.getCachedWorkout(id);
    if (cached != null) {
      return Workout.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    final workout = await service.getWorkout(id);
    await db.cacheWorkout(id, jsonEncode(workout.toJson()));
    return workout;
  }

  Future<Workout> saveWorkout(Workout workout) async {
    final saved = await service.saveWorkout(workout);
    await db.cacheWorkout(saved.id, jsonEncode(saved.toJson()));
    return saved;
  }

  Future<Workout> forkWorkout(String originalId, String newId) async {
    final forked = await service.forkWorkout(originalId, newId);
    await db.cacheWorkout(forked.id, jsonEncode(forked.toJson()));
    return forked;
  }

  Future<void> deleteWorkout(String id) async {
    await service.deleteWorkout(id);
    await db.removeCachedWorkout(id);
  }
}

// ── Test helpers ────────────────────────────────────────────────────────

Workout _makeWorkout({
  String id = 'wk-001',
  String title = 'Test Workout',
  bool isPublic = true,
  String authorId = 'user-xyz',
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? DateTime.utc(2025, 6, 1);
  return Workout(
    id: id,
    authorId: authorId,
    title: title,
    workoutType: WorkoutType.intervals,
    segments: const [
      WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.distance,
        durationValue: 500,
        targetIntensity: 95,
        targetStrokeRate: 28,
      ),
    ],
    tags: const ['sprint'],
    isPublic: isPublic,
    createdAt: now,
    updatedAt: now,
  );
}

TestableWorkoutRepository _build({
  FakeCacheDb? db,
  FakeWorkoutService? service,
  List<Workout>? workouts,
}) {
  return TestableWorkoutRepository(
    db: db ?? FakeCacheDb(),
    service: service ?? FakeWorkoutService(workouts ?? []),
  );
}

// ── Tests ───────────────────────────────────────────────────────────────

void main() {
  group('getWorkouts — cache-first reads', () {
    test('returns cached workouts without hitting the service', () async {
      final db = FakeCacheDb();
      final workout = _makeWorkout();
      await db.cacheWorkouts([workout]);

      final service = FakeWorkoutService([]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      final result = await repo.getWorkouts();

      expect(result.length, 1);
      expect(result.first.id, workout.id);
      expect(service.getWorkoutsCallCount, 0);
    });

    test('filters by isPublic when specified', () async {
      final db = FakeCacheDb();
      await db.cacheWorkouts([
        _makeWorkout(id: 'pub', isPublic: true),
        _makeWorkout(id: 'prv', isPublic: false),
      ]);
      final repo = _build(db: db);

      final publicOnly = await repo.getWorkouts(isPublic: true);
      expect(publicOnly.length, 1);
      expect(publicOnly.first.id, 'pub');

      final privateOnly = await repo.getWorkouts(isPublic: false);
      expect(privateOnly.length, 1);
      expect(privateOnly.first.id, 'prv');
    });

    test('filters by authorId when specified', () async {
      final db = FakeCacheDb();
      await db.cacheWorkouts([
        _makeWorkout(id: 'mine', authorId: 'alice'),
        _makeWorkout(id: 'theirs', authorId: 'bob'),
      ]);
      final repo = _build(db: db);

      final mine = await repo.getWorkouts(authorId: 'alice');
      expect(mine.length, 1);
      expect(mine.first.id, 'mine');
    });

    test('returns empty list when cache is empty', () async {
      final repo = _build();
      final result = await repo.getWorkouts();
      expect(result, isEmpty);
    });

    test('Workout survives JSON roundtrip through cache', () async {
      final db = FakeCacheDb();
      final original = _makeWorkout();
      await db.cacheWorkouts([original]);
      final repo = _build(db: db);

      final result = await repo.getWorkouts();
      final restored = result.first;

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.workoutType, original.workoutType);
      expect(restored.segments.length, 1);
      expect(restored.segments.first.targetIntensity, 95);
      expect(restored.tags, ['sprint']);
    });
  });

  group('refreshWorkouts — first sync (no lastSyncedAt)', () {
    test('calls getWorkouts (full fetch) when no lastSyncedAt', () async {
      final workout = _makeWorkout();
      final service = FakeWorkoutService([workout]);
      final repo = _build(service: service);

      await repo.refreshWorkouts();

      expect(service.getWorkoutsCallCount, 1);
      expect(service.getWorkoutsUpdatedSinceCallCount, 0);
    });

    test('populates cache on first sync', () async {
      final db = FakeCacheDb();
      final workout = _makeWorkout();
      final repo = _build(db: db, workouts: [workout]);

      await repo.refreshWorkouts();

      expect(db.hasCached(workout.id), isTrue);
      expect(db.cachedCount, 1);
    });

    test('sets scope-specific lastSyncedAt after first sync', () async {
      final db = FakeCacheDb();
      final repo = _build(db: db, workouts: [_makeWorkout()]);

      await repo.refreshWorkouts(isPublic: true);

      expect(db.getMeta('public_workouts_last_synced_at'), isNotNull);
      // User-scope key is untouched
      expect(db.getMeta('my_workouts_user-xyz_last_synced_at'), isNull);
    });

    test('runs full sync on first call (needsFullSync=true)', () async {
      final db = FakeCacheDb();
      final service = FakeWorkoutService([_makeWorkout()]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.refreshWorkouts(isPublic: true);

      expect(service.getWorkoutIdsCallCount, 1);
      expect(db.getMeta('public_workouts_last_full_sync_at'), isNotNull);
    });
  });

  group('refreshWorkouts — incremental sync', () {
    test('calls getWorkoutsUpdatedSince when lastSyncedAt is set', () async {
      final db = FakeCacheDb();
      await db.setSyncMeta('public_workouts_last_synced_at', '2025-06-01T00:00:00.000Z');
      await db.setSyncMeta(
          'public_workouts_last_full_sync_at', DateTime.now().toIso8601String());

      final workout = _makeWorkout(updatedAt: DateTime.utc(2025, 6, 2));
      final service = FakeWorkoutService([workout]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.refreshWorkouts(isPublic: true);

      expect(service.getWorkoutsUpdatedSinceCallCount, 1);
      expect(service.getWorkoutsCallCount, 0);
    });

    test('only new/updated workouts are upserted into cache', () async {
      final db = FakeCacheDb();
      final old = _makeWorkout(id: 'old', updatedAt: DateTime.utc(2025, 5, 1));
      await db.cacheWorkouts([old]);
      await db.setSyncMeta('public_workouts_last_synced_at', '2025-06-01T00:00:00.000Z');
      await db.setSyncMeta(
          'public_workouts_last_full_sync_at', DateTime.now().toIso8601String());

      final recent = _makeWorkout(id: 'new', updatedAt: DateTime.utc(2025, 6, 2));
      final service = FakeWorkoutService([recent]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.refreshWorkouts(isPublic: true);

      expect(db.cachedCount, 2);
      expect(db.hasCached('old'), isTrue);
      expect(db.hasCached('new'), isTrue);
    });

    test('does not run full sync when lastFullSync is recent', () async {
      final db = FakeCacheDb();
      await db.setSyncMeta('public_workouts_last_synced_at', '2025-06-01T00:00:00.000Z');
      await db.setSyncMeta(
          'public_workouts_last_full_sync_at', DateTime.now().toIso8601String());

      final service = FakeWorkoutService([_makeWorkout()]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.refreshWorkouts(isPublic: true);

      expect(service.getWorkoutIdsCallCount, 0);
    });

    test('user-scope and public-scope use independent metadata keys', () async {
      final db = FakeCacheDb();
      final publicWorkout = _makeWorkout(id: 'pub', isPublic: true, authorId: 'other');
      final userWorkout = _makeWorkout(id: 'usr', isPublic: false, authorId: 'alice');

      final service = FakeWorkoutService([publicWorkout, userWorkout]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      // Sync public library
      await repo.refreshWorkouts(isPublic: true);
      expect(db.getMeta('public_workouts_last_synced_at'), isNotNull);
      expect(db.getMeta('my_workouts_alice_last_synced_at'), isNull);

      // Sync user's workouts — should be a fresh full fetch, not incremental
      await repo.refreshWorkouts(authorId: 'alice');
      expect(service.getWorkoutsCallCount, 2); // both were full fetches
      expect(db.getMeta('my_workouts_alice_last_synced_at'), isNotNull);
    });
  });

  group('refreshWorkouts — delete detection (scoped)', () {
    test('removes public workouts absent from remote, leaves user workouts', () async {
      final db = FakeCacheDb();
      // Cache has public wk-a, public wk-b (deleted remotely), and user wk-c
      await db.cacheWorkouts([
        _makeWorkout(id: 'wk-a', isPublic: true, authorId: 'other'),
        _makeWorkout(id: 'wk-b', isPublic: true, authorId: 'other'),
        _makeWorkout(id: 'wk-c', isPublic: false, authorId: 'alice'),
      ]);
      await db.setSyncMeta(
        'public_workouts_last_full_sync_at',
        DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
      );
      await db.setSyncMeta('public_workouts_last_synced_at', '2025-06-01T00:00:00.000Z');

      // Remote only has wk-a (wk-b was deleted)
      final service = FakeWorkoutService([
        _makeWorkout(id: 'wk-a', isPublic: true, authorId: 'other'),
      ]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.refreshWorkouts(isPublic: true);

      expect(db.hasCached('wk-a'), isTrue, reason: 'still exists remotely');
      expect(db.hasCached('wk-b'), isFalse, reason: 'deleted remotely, in scope');
      expect(db.hasCached('wk-c'), isTrue, reason: 'user workout, out of scope');
    });

    test('user-scope delete detection leaves public workouts untouched', () async {
      final db = FakeCacheDb();
      await db.cacheWorkouts([
        _makeWorkout(id: 'pub', isPublic: true, authorId: 'other'),
        _makeWorkout(id: 'usr-a', isPublic: false, authorId: 'alice'),
        _makeWorkout(id: 'usr-b', isPublic: false, authorId: 'alice'),
      ]);
      await db.setSyncMeta(
        'my_workouts_alice_last_full_sync_at',
        DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
      );
      await db.setSyncMeta('my_workouts_alice_last_synced_at', '2025-06-01T00:00:00.000Z');

      // Remote only has usr-a (usr-b was deleted)
      final service = FakeWorkoutService([
        _makeWorkout(id: 'usr-a', isPublic: false, authorId: 'alice'),
      ]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.refreshWorkouts(authorId: 'alice');

      expect(db.hasCached('pub'), isTrue, reason: 'public workout, out of scope');
      expect(db.hasCached('usr-a'), isTrue, reason: 'still exists remotely');
      expect(db.hasCached('usr-b'), isFalse, reason: 'deleted remotely, in scope');
    });

    test('updates scope-specific lastFullSync timestamp after full sync', () async {
      final db = FakeCacheDb();
      final before = DateTime.now().subtract(const Duration(hours: 25));
      await db.setSyncMeta('public_workouts_last_full_sync_at', before.toIso8601String());
      await db.setSyncMeta('public_workouts_last_synced_at', '2025-06-01T00:00:00.000Z');

      final repo = _build(db: db, workouts: [_makeWorkout()]);

      await repo.refreshWorkouts(isPublic: true);

      final after = DateTime.parse(db.getMeta('public_workouts_last_full_sync_at')!);
      expect(after.isAfter(before), isTrue);
    });
  });

  group('refreshWorkouts — offline fallback', () {
    test('returns null on network error (cache unchanged)', () async {
      final db = FakeCacheDb();
      final cached = _makeWorkout(id: 'cached');
      await db.cacheWorkouts([cached]);

      final service = FakeWorkoutService([])..shouldThrow = true;
      final repo = TestableWorkoutRepository(db: db, service: service);

      final result = await repo.refreshWorkouts();

      expect(result, isNull);
      expect(db.hasCached('cached'), isTrue);
    });

    test('does not update lastSyncedAt on network error', () async {
      final db = FakeCacheDb();
      final service = FakeWorkoutService([])..shouldThrow = true;
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.refreshWorkouts(isPublic: true);

      expect(db.getMeta('public_workouts_last_synced_at'), isNull);
    });
  });

  group('refreshWorkouts — minInterval throttle', () {
    test('skips network when last sync was within minInterval', () async {
      final db = FakeCacheDb();
      // Last sync was 1 minute ago
      await db.setSyncMeta(
        'public_workouts_last_synced_at',
        DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
      );

      final service = FakeWorkoutService([_makeWorkout()]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      final result = await repo.refreshWorkouts(
        isPublic: true,
        minInterval: const Duration(minutes: 5),
      );

      expect(result, isNull);
      expect(service.getWorkoutsCallCount, 0);
      expect(service.getWorkoutsUpdatedSinceCallCount, 0);
    });

    test('hits network when last sync is older than minInterval', () async {
      final db = FakeCacheDb();
      // Last sync was 10 minutes ago
      await db.setSyncMeta(
        'public_workouts_last_synced_at',
        DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
      );
      await db.setSyncMeta(
          'public_workouts_last_full_sync_at', DateTime.now().toIso8601String());

      final service = FakeWorkoutService([_makeWorkout()]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.refreshWorkouts(
        isPublic: true,
        minInterval: const Duration(minutes: 5),
      );

      expect(service.getWorkoutsUpdatedSinceCallCount, 1);
    });

    test('always hits network when minInterval is zero (default)', () async {
      final db = FakeCacheDb();
      await db.setSyncMeta(
        'public_workouts_last_synced_at',
        DateTime.now().toIso8601String(), // just synced
      );
      await db.setSyncMeta(
          'public_workouts_last_full_sync_at', DateTime.now().toIso8601String());

      final service = FakeWorkoutService([_makeWorkout()]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.refreshWorkouts(isPublic: true); // no minInterval

      expect(service.getWorkoutsUpdatedSinceCallCount, 1);
    });
  });

  group('getWorkout — single workout', () {
    test('returns from cache without hitting network', () async {
      final db = FakeCacheDb();
      final workout = _makeWorkout();
      await db.cacheWorkouts([workout]);

      final service = FakeWorkoutService([]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      final result = await repo.getWorkout(workout.id);

      expect(result.id, workout.id);
      expect(service.getWorkoutCallCount, 0);
    });

    test('fetches from network on cache miss and caches the result', () async {
      final db = FakeCacheDb();
      final workout = _makeWorkout();
      final service = FakeWorkoutService([workout]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      final result = await repo.getWorkout(workout.id);

      expect(result.id, workout.id);
      expect(service.getWorkoutCallCount, 1);
      expect(db.hasCached(workout.id), isTrue);
    });

    test('second call after network fetch hits cache, not network', () async {
      final db = FakeCacheDb();
      final workout = _makeWorkout();
      final service = FakeWorkoutService([workout]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.getWorkout(workout.id);
      await repo.getWorkout(workout.id);

      expect(service.getWorkoutCallCount, 1);
    });
  });

  group('saveWorkout — write-through', () {
    test('saves to service and caches result', () async {
      final db = FakeCacheDb();
      final workout = _makeWorkout();
      final service = FakeWorkoutService([]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.saveWorkout(workout);

      expect(service.saveCallCount, 1);
      expect(db.hasCached(workout.id), isTrue);
    });

    test('cached version matches what service returned', () async {
      final db = FakeCacheDb();
      final workout = _makeWorkout(title: 'Original');
      final service = FakeWorkoutService([]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.saveWorkout(workout);

      final cachedJson = await db.getCachedWorkout(workout.id);
      final restored =
          Workout.fromJson(jsonDecode(cachedJson!) as Map<String, dynamic>);
      expect(restored.title, 'Original');
    });
  });

  group('forkWorkout — write-through', () {
    test('caches the forked workout under its new ID', () async {
      final db = FakeCacheDb();
      final original = _makeWorkout(id: 'orig');
      final service = FakeWorkoutService([original]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      final forked = await repo.forkWorkout('orig', 'fork');

      expect(db.hasCached('fork'), isTrue);
      expect(db.hasCached('orig'), isFalse); // original not separately cached
      expect(forked.id, 'fork');
      expect(forked.title, contains('fork'));
    });

    test('forked workout survives JSON roundtrip in cache', () async {
      final db = FakeCacheDb();
      final original = _makeWorkout(id: 'orig', title: 'My Workout');
      final service = FakeWorkoutService([original]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.forkWorkout('orig', 'fork');

      final cachedJson = await db.getCachedWorkout('fork');
      final restored =
          Workout.fromJson(jsonDecode(cachedJson!) as Map<String, dynamic>);
      expect(restored.id, 'fork');
    });
  });

  group('deleteWorkout — write-through', () {
    test('deletes from service and removes from cache', () async {
      final db = FakeCacheDb();
      final workout = _makeWorkout();
      await db.cacheWorkouts([workout]);

      final service = FakeWorkoutService([workout]);
      final repo = TestableWorkoutRepository(db: db, service: service);

      await repo.deleteWorkout(workout.id);

      expect(service.deleteCallCount, 1);
      expect(db.hasCached(workout.id), isFalse);
    });
  });
}
