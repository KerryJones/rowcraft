// Regression test for the "own private workouts never appear" bug.
//
// A user who authored *public* workouts has own-scoped rows in the cache
// without the own scope ever syncing. The old short-circuit treated
// "cachedOwn.isNotEmpty" as "own scope synced" → the fresh fetch that pulls
// private workouts was skipped. workoutLibraryProvider must instead gate on
// real sync state (hasEverSynced) and take the fresh path on first open.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rowcraft/features/auth/auth_provider.dart'
    show currentUserProvider;
import 'package:rowcraft/features/library/library_provider.dart';
import 'package:rowcraft/models/workout.dart';
import 'package:rowcraft/models/workout_segment.dart';
import 'package:rowcraft/services/workout_repository.dart';

Workout _w(
  String id, {
  bool isPublic = true,
  String authorId = 'alice',
}) {
  final now = DateTime.parse('2026-01-01T00:00:00.000Z');
  return Workout(
    id: id,
    authorId: authorId,
    title: id,
    workoutType: WorkoutType.intervals,
    segments: const [
      WorkoutSegment(
        durationType: DurationType.distance,
        durationValue: 2000,
      ),
    ],
    isPublic: isPublic,
    createdAt: now,
    updatedAt: now,
  );
}

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: '',
      createdAt: '2026-01-01T00:00:00.000Z',
    );

/// Fake repository backed by in-memory lists. Only the methods
/// workoutLibraryProvider touches are implemented; the rest throw.
class _FakeRepo implements WorkoutRepository {
  _FakeRepo({
    required this.cachedPublic,
    required this.cachedOwn,
    required this.ownSynced,
    required this.freshOwn,
  });

  final List<Workout> cachedPublic;
  final List<Workout> cachedOwn;
  final bool ownSynced;
  final List<Workout> freshOwn;

  // Split by minInterval: the fresh path calls own refresh with no interval
  // (blocking); the short-circuit path fires a throttled background refresh.
  int syncRefreshOwnCallCount = 0;
  int backgroundRefreshOwnCallCount = 0;

  @override
  Future<List<Workout>> getWorkouts({bool? isPublic, String? authorId}) async {
    if (isPublic == true) return cachedPublic;
    if (authorId != null) return cachedOwn;
    return [...cachedPublic, ...cachedOwn];
  }

  @override
  Future<bool> hasEverSynced({bool? isPublic, String? authorId}) async {
    if (authorId != null) return ownSynced;
    return true;
  }

  @override
  Future<List<Workout>?> refreshWorkouts({
    bool? isPublic,
    String? authorId,
    Duration minInterval = Duration.zero,
  }) async {
    if (isPublic == true) return cachedPublic;
    if (authorId != null) {
      if (minInterval == Duration.zero) {
        syncRefreshOwnCallCount++;
      } else {
        backgroundRefreshOwnCallCount++;
      }
      return freshOwn;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('workoutLibraryProvider — own-scope sync gating', () {
    test(
        'takes fresh path when own scope never synced, includes private workout',
        () async {
      // The user authored a public workout (so cachedOwn is non-empty via the
      // public cache), but the own scope has never synced. The private workout
      // only exists on the fresh own fetch.
      final publicOwn = _w('pub-by-alice', isPublic: true, authorId: 'alice');
      final privateOwn = _w('private-1', isPublic: false, authorId: 'alice');
      final otherPublic = _w('pub-other', isPublic: true, authorId: 'bob');

      final repo = _FakeRepo(
        cachedPublic: [otherPublic, publicOwn],
        cachedOwn: [publicOwn], // authored-public rows leaked into own cache
        ownSynced: false, // <-- the crux: never actually synced
        freshOwn: [publicOwn, privateOwn],
      );

      final container = ProviderContainer(overrides: [
        workoutRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(_user('alice')),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(workoutLibraryProvider.future);
      final ids = result.map((w) => w.id).toSet();

      expect(repo.syncRefreshOwnCallCount, 1,
          reason: 'fresh own fetch must be awaited, not fire-and-forget');
      expect(repo.backgroundRefreshOwnCallCount, 0);
      expect(ids, contains('private-1'),
          reason: 'private workout appears on first library open');
      expect(ids, contains('pub-other'));
      expect(ids.length, 3, reason: 'deduped across public + own');
    });

    test('short-circuits to cache when own scope has synced', () async {
      final privateOwn = _w('private-1', isPublic: false, authorId: 'alice');
      final otherPublic = _w('pub-other', isPublic: true, authorId: 'bob');

      final repo = _FakeRepo(
        cachedPublic: [otherPublic],
        cachedOwn: [privateOwn],
        ownSynced: true, // already synced → trust the cache
        freshOwn: [privateOwn],
      );

      final container = ProviderContainer(overrides: [
        workoutRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(_user('alice')),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(workoutLibraryProvider.future);
      final ids = result.map((w) => w.id).toSet();

      expect(ids, containsAll(['pub-other', 'private-1']));
      expect(repo.syncRefreshOwnCallCount, 0,
          reason: 'short-circuit must not block on a fresh own fetch');
      expect(repo.backgroundRefreshOwnCallCount, 1,
          reason: 'background own refresh is still kicked off');
    });
  });
}
