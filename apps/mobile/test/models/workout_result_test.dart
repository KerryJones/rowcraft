import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_result.dart';

void main() {
  final startedAt = DateTime.utc(2025, 6, 15, 10, 0, 0);
  final finishedAt = DateTime.utc(2025, 6, 15, 10, 30, 0);

  Map<String, dynamic> _splitJson({
    int segmentIndex = 0,
    double distance = 500.0,
    int timeMs = 105000,
    int avgPace = 1050,
    int avgStrokeRate = 28,
    int avgWatts = 200,
    int? avgHeartRate = 155,
    int calories = 30,
  }) =>
      {
        'segment_index': segmentIndex,
        'distance': distance,
        'time_ms': timeMs,
        'avg_pace': avgPace,
        'avg_stroke_rate': avgStrokeRate,
        'avg_watts': avgWatts,
        if (avgHeartRate != null) 'avg_heart_rate': avgHeartRate,
        'calories': calories,
      };

  Map<String, dynamic> _resultJson({
    String id = 'result-001',
    String userId = 'user-xyz',
    String? workoutId = 'wk-abc',
    int totalTimeMs = 1800000,
    double totalDistance = 6000.0,
    int avgSplit = 1050,
    int avgStrokeRate = 28,
    int? avgHeartRate = 150,
    int avgWatts = 195,
    int calories = 350,
    List<Map<String, dynamic>>? splits,
    bool syncedToC2 = false,
  }) =>
      {
        'id': id,
        'user_id': userId,
        if (workoutId != null) 'workout_id': workoutId,
        'started_at': startedAt.toIso8601String(),
        'finished_at': finishedAt.toIso8601String(),
        'total_distance': totalDistance,
        'total_time_ms': totalTimeMs,
        'avg_split': avgSplit,
        'avg_stroke_rate': avgStrokeRate,
        if (avgHeartRate != null) 'avg_heart_rate': avgHeartRate,
        'avg_watts': avgWatts,
        'calories': calories,
        'splits': splits ?? [_splitJson(segmentIndex: 0), _splitJson(segmentIndex: 1)],
        'synced_to_c2': syncedToC2,
      };

  group('SplitData', () {
    group('fromJson', () {
      test('deserializes all fields using segment_index key', () {
        final json = _splitJson(segmentIndex: 2);
        final split = SplitData.fromJson(json);

        expect(split.intervalIndex, 2);
        expect(split.distance, 500.0);
        expect(split.time, const Duration(milliseconds: 105000));
        expect(split.avgPace, 1050);
        expect(split.avgStrokeRate, 28);
        expect(split.avgWatts, 200);
        expect(split.avgHeartRate, 155);
        expect(split.calories, 30);
      });

      test('handles null avgHeartRate', () {
        final json = _splitJson(avgHeartRate: null);
        final split = SplitData.fromJson(json);
        expect(split.avgHeartRate, isNull);
      });
    });

    group('toJson', () {
      test('serializes using segment_index key (not interval_index)', () {
        final json = _splitJson(segmentIndex: 3);
        final split = SplitData.fromJson(json);
        final output = split.toJson();

        expect(output.containsKey('segment_index'), isTrue);
        expect(output.containsKey('interval_index'), isFalse);
        expect(output['segment_index'], 3);
      });

      test('omits avg_heart_rate when null', () {
        final json = _splitJson(avgHeartRate: null);
        final split = SplitData.fromJson(json);
        final output = split.toJson();

        expect(output.containsKey('avg_heart_rate'), isFalse);
      });

      test('includes avg_heart_rate when present', () {
        final json = _splitJson(avgHeartRate: 160);
        final split = SplitData.fromJson(json);
        final output = split.toJson();

        expect(output['avg_heart_rate'], 160);
      });
    });

    group('fromJson/toJson roundtrip', () {
      test('full split data survives roundtrip', () {
        final original = _splitJson(segmentIndex: 4, avgHeartRate: 162);
        final split = SplitData.fromJson(original);
        final json = split.toJson();
        final roundtripped = SplitData.fromJson(json);

        expect(roundtripped.intervalIndex, split.intervalIndex);
        expect(roundtripped.distance, split.distance);
        expect(roundtripped.time, split.time);
        expect(roundtripped.avgPace, split.avgPace);
        expect(roundtripped.avgStrokeRate, split.avgStrokeRate);
        expect(roundtripped.avgWatts, split.avgWatts);
        expect(roundtripped.avgHeartRate, split.avgHeartRate);
        expect(roundtripped.calories, split.calories);
      });

      test('split without heart rate survives roundtrip', () {
        final original = _splitJson(avgHeartRate: null);
        final split = SplitData.fromJson(original);
        final json = split.toJson();
        final roundtripped = SplitData.fromJson(json);

        expect(roundtripped.avgHeartRate, isNull);
      });
    });

    group('paceFormatted', () {
      test('formats 1:45.0 correctly', () {
        // 1:45.0 = 1*600 + 45*10 + 0 = 1050
        final split = SplitData.fromJson(_splitJson(avgPace: 1050));
        expect(split.paceFormatted, '1:45.0');
      });

      test('formats 2:00.0 correctly', () {
        // 2:00.0 = 2*600 = 1200
        final split = SplitData.fromJson(_splitJson(avgPace: 1200));
        expect(split.paceFormatted, '2:00.0');
      });

      test('formats 1:30.5 correctly', () {
        // 1:30.5 = 1*600 + 30*10 + 5 = 905
        final split = SplitData.fromJson(_splitJson(avgPace: 905));
        expect(split.paceFormatted, '1:30.5');
      });

      test('formats 2:05.3 correctly', () {
        // 2:05.3 = 2*600 + 5*10 + 3 = 1253
        final split = SplitData.fromJson(_splitJson(avgPace: 1253));
        expect(split.paceFormatted, '2:05.3');
      });

      test('formats sub-minute pace correctly', () {
        // 0:55.0 = 0*600 + 55*10 + 0 = 550
        final split = SplitData.fromJson(_splitJson(avgPace: 550));
        expect(split.paceFormatted, '0:55.0');
      });
    });
  });

  group('WorkoutResult', () {
    group('fromJson', () {
      test('deserializes all fields from realistic JSON', () {
        final json = _resultJson();
        final result = WorkoutResult.fromJson(json);

        expect(result.id, 'result-001');
        expect(result.userId, 'user-xyz');
        expect(result.workoutId, 'wk-abc');
        expect(result.startedAt, startedAt);
        expect(result.finishedAt, finishedAt);
        expect(result.totalDistance, 6000.0);
        expect(result.totalTime, const Duration(milliseconds: 1800000));
        expect(result.avgSplit, 1050);
        expect(result.avgStrokeRate, 28);
        expect(result.avgHeartRate, 150);
        expect(result.avgWatts, 195);
        expect(result.calories, 350);
        expect(result.splits, hasLength(2));
        expect(result.syncedToC2, false);
      });

      test('handles null workoutId', () {
        final json = _resultJson(workoutId: null);
        final result = WorkoutResult.fromJson(json);
        expect(result.workoutId, isNull);
      });

      test('handles null avgHeartRate', () {
        final json = _resultJson(avgHeartRate: null);
        final result = WorkoutResult.fromJson(json);
        expect(result.avgHeartRate, isNull);
      });

      test('handles missing splits', () {
        final json = _resultJson();
        json.remove('splits');
        final result = WorkoutResult.fromJson(json);
        expect(result.splits, isEmpty);
      });

      test('handles missing synced_to_c2 defaults to false', () {
        final json = _resultJson();
        json.remove('synced_to_c2');
        final result = WorkoutResult.fromJson(json);
        expect(result.syncedToC2, false);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final json = _resultJson();
        final result = WorkoutResult.fromJson(json);
        final output = result.toJson();

        expect(output['id'], 'result-001');
        expect(output['user_id'], 'user-xyz');
        expect(output['workout_id'], 'wk-abc');
        expect(output['total_distance'], 6000.0);
        expect(output['total_time_ms'], 1800000);
        expect(output['avg_split'], 1050);
        expect(output['avg_stroke_rate'], 28);
        expect(output['avg_heart_rate'], 150);
        expect(output['avg_watts'], 195);
        expect(output['calories'], 350);
        expect(output['splits'], hasLength(2));
        expect(output['synced_to_c2'], false);
      });

      test('omits workout_id when null', () {
        final json = _resultJson(workoutId: null);
        final result = WorkoutResult.fromJson(json);
        final output = result.toJson();
        expect(output.containsKey('workout_id'), isFalse);
      });

      test('omits avg_heart_rate when null', () {
        final json = _resultJson(avgHeartRate: null);
        final result = WorkoutResult.fromJson(json);
        final output = result.toJson();
        expect(output.containsKey('avg_heart_rate'), isFalse);
      });
    });

    group('fromJson/toJson roundtrip', () {
      test('full result survives roundtrip', () {
        final original = _resultJson();
        final result = WorkoutResult.fromJson(original);
        final json = result.toJson();
        final roundtripped = WorkoutResult.fromJson(json);

        expect(roundtripped.id, result.id);
        expect(roundtripped.userId, result.userId);
        expect(roundtripped.workoutId, result.workoutId);
        expect(roundtripped.startedAt, result.startedAt);
        expect(roundtripped.finishedAt, result.finishedAt);
        expect(roundtripped.totalDistance, result.totalDistance);
        expect(roundtripped.totalTime, result.totalTime);
        expect(roundtripped.avgSplit, result.avgSplit);
        expect(roundtripped.avgStrokeRate, result.avgStrokeRate);
        expect(roundtripped.avgHeartRate, result.avgHeartRate);
        expect(roundtripped.avgWatts, result.avgWatts);
        expect(roundtripped.calories, result.calories);
        expect(roundtripped.splits.length, result.splits.length);
        expect(roundtripped.syncedToC2, result.syncedToC2);
      });

      test('result without optional fields survives roundtrip', () {
        final original = _resultJson(workoutId: null, avgHeartRate: null);
        final result = WorkoutResult.fromJson(original);
        final json = result.toJson();
        final roundtripped = WorkoutResult.fromJson(json);

        expect(roundtripped.workoutId, isNull);
        expect(roundtripped.avgHeartRate, isNull);
      });
    });

    group('avgSplitFormatted', () {
      test('formats 1:45.0 correctly (avgSplit=1050)', () {
        final result = WorkoutResult.fromJson(_resultJson(avgSplit: 1050));
        expect(result.avgSplitFormatted, '1:45.0');
      });

      test('formats 2:00.0 correctly (avgSplit=1200)', () {
        final result = WorkoutResult.fromJson(_resultJson(avgSplit: 1200));
        expect(result.avgSplitFormatted, '2:00.0');
      });

      test('formats 1:58.7 correctly (avgSplit=1187)', () {
        // 1*600 + 58*10 + 7 = 1187
        final result = WorkoutResult.fromJson(_resultJson(avgSplit: 1187));
        expect(result.avgSplitFormatted, '1:58.7');
      });
    });

    group('totalTimeFormatted', () {
      test('formats 30 minutes as 30:00', () {
        // 30 min = 1800000 ms
        final result = WorkoutResult.fromJson(
            _resultJson(totalTimeMs: 1800000));
        expect(result.totalTimeFormatted, '30:00');
      });

      test('formats 1 hour 5 minutes 30 seconds as 1:05:30', () {
        // 1h 5m 30s = 3930000 ms
        final result = WorkoutResult.fromJson(
            _resultJson(totalTimeMs: 3930000));
        expect(result.totalTimeFormatted, '1:05:30');
      });

      test('formats 5 minutes 9 seconds as 5:09', () {
        // 5m 9s = 309000 ms
        final result = WorkoutResult.fromJson(
            _resultJson(totalTimeMs: 309000));
        expect(result.totalTimeFormatted, '5:09');
      });

      test('formats exactly 1 hour as 1:00:00', () {
        final result = WorkoutResult.fromJson(
            _resultJson(totalTimeMs: 3600000));
        expect(result.totalTimeFormatted, '1:00:00');
      });

      test('formats sub-minute as 0:SS', () {
        // 45 seconds = 45000 ms
        final result = WorkoutResult.fromJson(
            _resultJson(totalTimeMs: 45000));
        expect(result.totalTimeFormatted, '0:45');
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final result = WorkoutResult.fromJson(_resultJson());
        final copied = result.copyWith(avgSplit: 1200);

        expect(copied.id, result.id);
        expect(copied.userId, result.userId);
        expect(copied.workoutId, result.workoutId);
        expect(copied.totalDistance, result.totalDistance);
        expect(copied.avgSplit, 1200);
        expect(copied.avgStrokeRate, result.avgStrokeRate);
        expect(copied.syncedToC2, result.syncedToC2);
      });

      test('can set syncedToC2 to true', () {
        final result = WorkoutResult.fromJson(_resultJson(syncedToC2: false));
        final copied = result.copyWith(syncedToC2: true);
        expect(copied.syncedToC2, true);
      });
    });

    group('equality', () {
      test('results with same id are equal', () {
        final a = WorkoutResult.fromJson(_resultJson(id: 'same'));
        final b = WorkoutResult.fromJson(
            _resultJson(id: 'same', avgSplit: 9999));
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('results with different ids are not equal', () {
        final a = WorkoutResult.fromJson(_resultJson(id: 'id-1'));
        final b = WorkoutResult.fromJson(_resultJson(id: 'id-2'));
        expect(a, isNot(equals(b)));
      });
    });
  });
}
