// Sync service serialization tests.
//
// These tests verify the JSON roundtrip paths that SyncService uses
// to queue and restore WorkoutResults, without depending on Drift
// (which requires code generation).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_result.dart';

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
    splits: const [
      SplitData(
        intervalIndex: 0,
        distance: 2000,
        time: Duration(minutes: 10),
        avgPace: 1050,
        avgStrokeRate: 28,
        avgWatts: 195,
        avgHeartRate: 150,
        calories: 120,
      ),
    ],
  );
}

void main() {
  group('SyncService serialization', () {
    test('WorkoutResult survives JSON encode/decode roundtrip', () {
      final original = _makeResult();
      final json = jsonEncode(original.toJson());
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final restored = WorkoutResult.fromJson(decoded);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.workoutId, original.workoutId);
      expect(restored.totalDistance, original.totalDistance);
      expect(restored.avgSplit, original.avgSplit);
      expect(restored.avgStrokeRate, original.avgStrokeRate);
      expect(restored.avgWatts, original.avgWatts);
      expect(restored.calories, original.calories);
      expect(restored.splits.length, 1);
      expect(restored.syncedToC2, false);
    });

    test('toJson contains all required Supabase fields', () {
      final result = _makeResult();
      final json = result.toJson();

      expect(json.containsKey('user_id'), isTrue);
      expect(json.containsKey('started_at'), isTrue);
      expect(json.containsKey('finished_at'), isTrue);
      expect(json.containsKey('total_distance'), isTrue);
      expect(json.containsKey('total_time'), isTrue);
      expect(json.containsKey('avg_split'), isTrue);
      expect(json.containsKey('avg_stroke_rate'), isTrue);
      expect(json.containsKey('avg_watts'), isTrue);
      expect(json.containsKey('calories'), isTrue);
      expect(json.containsKey('splits'), isTrue);
      expect(json.containsKey('synced_to_c2'), isTrue);
    });

    test('total_time is serialized as tenths of seconds', () {
      final result = _makeResult(); // totalTime = 30 minutes
      final json = result.toJson();

      // 30 minutes = 1800 seconds = 18000 tenths
      expect(json['total_time'], 18000);
    });

    test('total_distance is serialized as integer meters', () {
      final result = _makeResult(); // totalDistance = 6000.0
      final json = result.toJson();

      expect(json['total_distance'], 6000);
    });

    test('empty id is omitted from toJson', () {
      final result = _makeResult().copyWith(id: '');
      final json = result.toJson();

      expect(json.containsKey('id'), isFalse);
    });

    test('non-empty id is included in toJson', () {
      final result = _makeResult();
      final json = result.toJson();

      expect(json['id'], 'result-001');
    });

    test('split data uses segment_index key', () {
      final result = _makeResult();
      final json = result.toJson();
      final splits = json['splits'] as List;
      final firstSplit = splits.first as Map<String, dynamic>;

      expect(firstSplit.containsKey('segment_index'), isTrue);
      expect(firstSplit.containsKey('interval_index'), isFalse);
    });

    test('null workout_id excluded from JSON', () {
      final freeRow = WorkoutResult(
        id: 'free-row-1',
        userId: 'user-1',
        startedAt: DateTime.utc(2025, 3, 15, 10, 0),
        finishedAt: DateTime.utc(2025, 3, 15, 10, 15),
        totalDistance: 3000,
        totalTime: const Duration(minutes: 15),
        avgSplit: 1250,
        avgStrokeRate: 22,
        avgWatts: 160,
        calories: 200,
      );

      final json = freeRow.toJson();
      expect(json.containsKey('workout_id'), isFalse);
    });

    test('null avgHeartRate excluded from JSON', () {
      // _makeResult has avgHeartRate: 150, so copyWith to remove it
      // Note: copyWith can't set to null due to Dart limitation,
      // so we construct without it
      final noHr = WorkoutResult(
        id: 'no-hr',
        userId: 'user-1',
        startedAt: DateTime.utc(2025, 3, 15, 10, 0),
        finishedAt: DateTime.utc(2025, 3, 15, 10, 30),
        totalDistance: 6000,
        totalTime: const Duration(minutes: 30),
        avgSplit: 1050,
        avgStrokeRate: 28,
        avgWatts: 195,
        calories: 350,
      );

      final json = noHr.toJson();
      expect(json.containsKey('avg_heart_rate'), isFalse);
    });

    test('present avgHeartRate included in JSON', () {
      final result = _makeResult(); // has avgHeartRate: 150
      final json = result.toJson();
      expect(json['avg_heart_rate'], 150);
    });

    test('copyWith syncedToC2 preserves other fields', () {
      final original = _makeResult();
      final synced = original.copyWith(syncedToC2: true);

      expect(synced.syncedToC2, true);
      expect(synced.id, original.id);
      expect(synced.totalDistance, original.totalDistance);
      expect(synced.avgSplit, original.avgSplit);
      expect(synced.splits.length, original.splits.length);
    });

    test('fromJson handles total_time in tenths (DB format)', () {
      final json = {
        'id': 'r-1',
        'user_id': 'u-1',
        'started_at': '2025-01-15T10:00:00.000Z',
        'finished_at': '2025-01-15T10:30:00.000Z',
        'total_distance': 6000,
        'total_time': 18000, // 30 min in tenths
        'avg_split': 1200,
        'avg_stroke_rate': 24,
        'avg_watts': 180,
        'calories': 400,
      };

      final result = WorkoutResult.fromJson(json);
      expect(result.totalTime.inMinutes, 30);
    });

    test('fromJson handles missing total_time gracefully', () {
      final json = {
        'id': 'r-1',
        'user_id': 'u-1',
        'started_at': '2025-01-15T10:00:00.000Z',
        'finished_at': '2025-01-15T10:30:00.000Z',
        'total_distance': 6000,
        'avg_split': 1200,
        'avg_stroke_rate': 24,
        'avg_watts': 180,
        'calories': 400,
      };

      final result = WorkoutResult.fromJson(json);
      expect(result.totalTime, Duration.zero);
    });
  });
}
