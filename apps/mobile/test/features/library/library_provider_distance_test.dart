import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rowcraft/features/library/library_provider.dart';
import 'package:rowcraft/models/workout.dart';
import 'package:rowcraft/models/workout_segment.dart';

Workout _w(String id, List<WorkoutSegment> segments) {
  final now = DateTime.parse('2026-01-01T00:00:00.000Z');
  return Workout(
    id: id,
    authorId: 'author-1',
    title: id,
    workoutType: WorkoutType.intervals,
    segments: segments,
    createdAt: now,
    updatedAt: now,
  );
}

WorkoutSegment _dist(double meters) => WorkoutSegment(
      durationType: DurationType.distance,
      durationValue: meters,
    );

WorkoutSegment _time(double secs) => WorkoutSegment(
      durationType: DurationType.time,
      durationValue: secs,
    );

void main() {
  final timeOnly = _w('time-only', [_time(1200)]);
  final d1500 = _w('d-1500', [_dist(1500)]);
  final d3000 = _w('d-3000', [_dist(3000)]);
  final d7500 = _w('d-7500', [_dist(7500)]);
  final d15000 = _w('d-15000', [_dist(15000)]);
  final d5000Exact = _w('d-5000', [_dist(5000)]);
  final d10000Exact = _w('d-10000', [_dist(10000)]);
  final mixed2k = _w('mixed-2k', [_time(600), _dist(2000)]);

  final allWorkouts = [
    timeOnly,
    d1500,
    d3000,
    d7500,
    d15000,
    d5000Exact,
    d10000Exact,
    mixed2k,
  ];

  Future<List<Workout>> runFilter(DistanceFilter? distance) async {
    final container = ProviderContainer(overrides: [
      workoutLibraryProvider.overrideWith((_) async => allWorkouts),
    ]);
    addTearDown(container.dispose);
    return container.read(filteredWorkoutsProvider((
      search: null,
      type: null,
      tag: null,
      duration: null,
      distance: distance,
      hrZone: null,
      collectionKey: null,
      mine: false,
      sort: LibrarySortOrder.newest,
    )).future);
  }

  group('filteredWorkoutsProvider distance filter', () {
    test('under2k excludes time-only and distances ≥2000', () async {
      final result = await runFilter(DistanceFilter.under2k);
      expect(result.map((w) => w.id), unorderedEquals(['d-1500']));
    });

    test('2–5k includes [2000, 5000); excludes 5000 exact and time-only', () async {
      final result = await runFilter(DistanceFilter.from2to5k);
      expect(
        result.map((w) => w.id),
        unorderedEquals(['d-3000', 'mixed-2k']),
      );
    });

    test('5–10k includes [5000, 10000); excludes 10000 exact', () async {
      final result = await runFilter(DistanceFilter.from5to10k);
      expect(
        result.map((w) => w.id),
        unorderedEquals(['d-7500', 'd-5000']),
      );
    });

    test('10k+ includes 10000 exact and above', () async {
      final result = await runFilter(DistanceFilter.over10k);
      expect(
        result.map((w) => w.id),
        unorderedEquals(['d-15000', 'd-10000']),
      );
    });

    test('time-only workouts are never returned when a distance filter is active',
        () async {
      for (final bucket in DistanceFilter.values) {
        final result = await runFilter(bucket);
        expect(
          result.any((w) => w.id == 'time-only'),
          isFalse,
          reason: 'time-only leaked into $bucket',
        );
      }
    });

    test('null distance filter returns all workouts', () async {
      final result = await runFilter(null);
      expect(result.length, allWorkouts.length);
    });
  });
}
