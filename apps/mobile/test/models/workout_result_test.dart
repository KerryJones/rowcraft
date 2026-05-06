import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_result.dart';
import 'package:rowcraft/models/workout_time_sample.dart';

void main() {
  final startedAt = DateTime.utc(2025, 6, 15, 10, 0, 0);
  final finishedAt = DateTime.utc(2025, 6, 15, 10, 30, 0);

  Map<String, dynamic> splitJson({
    int segmentIndex = 0,
    double distance = 500.0,
    int timeMs = 105000,
    int avgPace = 1050,
    int avgStrokeRate = 28,
    int avgWatts = 200,
    int? avgHeartRate = 155,
    int calories = 30,
    bool? isRest,
  }) =>
      {
        'segment_index': segmentIndex,
        'distance': distance,
        'time_ms': timeMs,
        'avg_pace': avgPace,
        'avg_stroke_rate': avgStrokeRate,
        'avg_watts': avgWatts,
        'avg_heart_rate': ?avgHeartRate,
        'calories': calories,
        'is_rest': ?isRest,
      };

  Map<String, dynamic> resultJson({
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
        'workout_id': ?workoutId,
        'started_at': startedAt.toIso8601String(),
        'finished_at': finishedAt.toIso8601String(),
        'total_distance': totalDistance,
        'total_time_ms': totalTimeMs,
        'avg_split': avgSplit,
        'avg_stroke_rate': avgStrokeRate,
        'avg_heart_rate': ?avgHeartRate,
        'avg_watts': avgWatts,
        'calories': calories,
        'splits': splits ?? [splitJson(segmentIndex: 0), splitJson(segmentIndex: 1)],
        'synced_to_c2': syncedToC2,
      };

  group('SplitData', () {
    group('fromJson', () {
      test('deserializes all fields using segment_index key', () {
        final json = splitJson(segmentIndex: 2);
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
        final json = splitJson(avgHeartRate: null);
        final split = SplitData.fromJson(json);
        expect(split.avgHeartRate, isNull);
      });

      test('defaults isRest to false when missing', () {
        final json = splitJson();
        final split = SplitData.fromJson(json);
        expect(split.isRest, isFalse);
      });

      test('reads isRest=true when present', () {
        final json = splitJson(isRest: true);
        final split = SplitData.fromJson(json);
        expect(split.isRest, isTrue);
      });
    });

    group('toJson', () {
      test('serializes using segment_index key (not interval_index)', () {
        final json = splitJson(segmentIndex: 3);
        final split = SplitData.fromJson(json);
        final output = split.toJson();

        expect(output.containsKey('segment_index'), isTrue);
        expect(output.containsKey('interval_index'), isFalse);
        expect(output['segment_index'], 3);
      });

      test('omits avg_heart_rate when null', () {
        final json = splitJson(avgHeartRate: null);
        final split = SplitData.fromJson(json);
        final output = split.toJson();

        expect(output.containsKey('avg_heart_rate'), isFalse);
      });

      test('includes avg_heart_rate when present', () {
        final json = splitJson(avgHeartRate: 160);
        final split = SplitData.fromJson(json);
        final output = split.toJson();

        expect(output['avg_heart_rate'], 160);
      });

      test('omits is_rest when false', () {
        final split = SplitData.fromJson(splitJson());
        final output = split.toJson();

        expect(output.containsKey('is_rest'), isFalse);
      });

      test('includes is_rest=true when set', () {
        final split = SplitData.fromJson(splitJson(isRest: true));
        final output = split.toJson();

        expect(output['is_rest'], isTrue);
      });
    });

    group('fromJson/toJson roundtrip', () {
      test('full split data survives roundtrip', () {
        final original = splitJson(segmentIndex: 4, avgHeartRate: 162);
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
        final original = splitJson(avgHeartRate: null);
        final split = SplitData.fromJson(original);
        final json = split.toJson();
        final roundtripped = SplitData.fromJson(json);

        expect(roundtripped.avgHeartRate, isNull);
      });

      test('rest split survives roundtrip', () {
        final original = splitJson(isRest: true);
        final split = SplitData.fromJson(original);
        final json = split.toJson();
        final roundtripped = SplitData.fromJson(json);

        expect(roundtripped.isRest, isTrue);
      });
    });

    group('paceFormatted', () {
      test('formats 1:45 correctly', () {
        // 1:45 = 1*600 + 45*10 = 1050
        final split = SplitData.fromJson(splitJson(avgPace: 1050));
        expect(split.paceFormatted, '1:45');
      });

      test('formats 2:00 correctly', () {
        // 2:00 = 2*600 = 1200
        final split = SplitData.fromJson(splitJson(avgPace: 1200));
        expect(split.paceFormatted, '2:00');
      });

      test('formats 1:30 correctly', () {
        // 1:30 = 1*600 + 30*10 + 5 = 905
        final split = SplitData.fromJson(splitJson(avgPace: 905));
        expect(split.paceFormatted, '1:30');
      });

      test('formats 2:05 correctly', () {
        // 2:05 = 2*600 + 5*10 + 3 = 1253
        final split = SplitData.fromJson(splitJson(avgPace: 1253));
        expect(split.paceFormatted, '2:05');
      });

      test('formats sub-minute pace correctly', () {
        // 0:55 = 0*600 + 55*10 = 550
        final split = SplitData.fromJson(splitJson(avgPace: 550));
        expect(split.paceFormatted, '0:55');
      });
    });
  });

  group('WorkoutResult', () {
    group('fromJson', () {
      test('deserializes all fields from realistic JSON', () {
        final json = resultJson();
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
        final json = resultJson(workoutId: null);
        final result = WorkoutResult.fromJson(json);
        expect(result.workoutId, isNull);
      });

      test('handles null avgHeartRate', () {
        final json = resultJson(avgHeartRate: null);
        final result = WorkoutResult.fromJson(json);
        expect(result.avgHeartRate, isNull);
      });

      test('handles missing splits', () {
        final json = resultJson();
        json.remove('splits');
        final result = WorkoutResult.fromJson(json);
        expect(result.splits, isEmpty);
      });

      test('handles missing synced_to_c2 defaults to false', () {
        final json = resultJson();
        json.remove('synced_to_c2');
        final result = WorkoutResult.fromJson(json);
        expect(result.syncedToC2, false);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final json = resultJson();
        final result = WorkoutResult.fromJson(json);
        final output = result.toJson();

        expect(output['id'], 'result-001');
        expect(output['user_id'], 'user-xyz');
        expect(output['workout_id'], 'wk-abc');
        expect(output['total_distance'], 6000.0);
        expect(output['total_time'], 18000); // tenths of seconds (DB format)
        expect(output['avg_split'], 1050);
        expect(output['avg_stroke_rate'], 28);
        expect(output['avg_heart_rate'], 150);
        expect(output['avg_watts'], 195);
        expect(output['calories'], 350);
        expect(output['splits'], hasLength(2));
        expect(output['synced_to_c2'], false);
      });

      test('omits workout_id when null', () {
        final json = resultJson(workoutId: null);
        final result = WorkoutResult.fromJson(json);
        final output = result.toJson();
        expect(output.containsKey('workout_id'), isFalse);
      });

      test('omits avg_heart_rate when null', () {
        final json = resultJson(avgHeartRate: null);
        final result = WorkoutResult.fromJson(json);
        final output = result.toJson();
        expect(output.containsKey('avg_heart_rate'), isFalse);
      });
    });

    group('fromJson/toJson roundtrip', () {
      test('full result survives roundtrip', () {
        final original = resultJson();
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
        final original = resultJson(workoutId: null, avgHeartRate: null);
        final result = WorkoutResult.fromJson(original);
        final json = result.toJson();
        final roundtripped = WorkoutResult.fromJson(json);

        expect(roundtripped.workoutId, isNull);
        expect(roundtripped.avgHeartRate, isNull);
      });
    });

    group('avgSplitFormatted', () {
      test('formats 1:45 correctly (avgSplit=1050)', () {
        final result = WorkoutResult.fromJson(resultJson(avgSplit: 1050));
        expect(result.avgSplitFormatted, '1:45');
      });

      test('formats 2:00 correctly (avgSplit=1200)', () {
        final result = WorkoutResult.fromJson(resultJson(avgSplit: 1200));
        expect(result.avgSplitFormatted, '2:00');
      });

      test('formats 1:58 correctly (avgSplit=1187)', () {
        // 1*600 + 58*10 + 7 = 1187
        final result = WorkoutResult.fromJson(resultJson(avgSplit: 1187));
        expect(result.avgSplitFormatted, '1:58');
      });
    });

    group('totalTimeFormatted', () {
      test('formats 30 minutes as 30:00', () {
        // 30 min = 1800000 ms
        final result = WorkoutResult.fromJson(
            resultJson(totalTimeMs: 1800000));
        expect(result.totalTimeFormatted, '30:00');
      });

      test('formats 1 hour 5 minutes 30 seconds as 1:05:30', () {
        // 1h 5m 30s = 3930000 ms
        final result = WorkoutResult.fromJson(
            resultJson(totalTimeMs: 3930000));
        expect(result.totalTimeFormatted, '1:05:30');
      });

      test('formats 5 minutes 9 seconds as 5:09', () {
        // 5m 9s = 309000 ms
        final result = WorkoutResult.fromJson(
            resultJson(totalTimeMs: 309000));
        expect(result.totalTimeFormatted, '5:09');
      });

      test('formats exactly 1 hour as 1:00:00', () {
        final result = WorkoutResult.fromJson(
            resultJson(totalTimeMs: 3600000));
        expect(result.totalTimeFormatted, '1:00:00');
      });

      test('formats sub-minute as 0:SS', () {
        // 45 seconds = 45000 ms
        final result = WorkoutResult.fromJson(
            resultJson(totalTimeMs: 45000));
        expect(result.totalTimeFormatted, '0:45');
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final result = WorkoutResult.fromJson(resultJson());
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
        final result = WorkoutResult.fromJson(resultJson(syncedToC2: false));
        final copied = result.copyWith(syncedToC2: true);
        expect(copied.syncedToC2, true);
      });
    });

    group('equality', () {
      test('results with same id are equal', () {
        final a = WorkoutResult.fromJson(resultJson(id: 'same'));
        final b = WorkoutResult.fromJson(
            resultJson(id: 'same', avgSplit: 9999));
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('results with different ids are not equal', () {
        final a = WorkoutResult.fromJson(resultJson(id: 'id-1'));
        final b = WorkoutResult.fromJson(resultJson(id: 'id-2'));
        expect(a, isNot(equals(b)));
      });
    });

    group('C2 detail fields', () {
      test('deserializes new C2 detail fields', () {
        final json = resultJson();
        json['stroke_count'] = 450;
        json['drag_factor'] = 115;
        json['min_heart_rate'] = 120;
        json['max_heart_rate'] = 175;
        json['ending_heart_rate'] = 168;
        json['timezone'] = 'America/New_York';
        json['time_samples'] = [
          {'t': 1000, 'd': 5.2, 'p': 1050, 'spm': 28, 'hr': 145, 'si': 0},
          {'t': 2000, 'd': 10.5, 'p': 1040, 'spm': 29, 'si': 0},
        ];

        final result = WorkoutResult.fromJson(json);

        expect(result.strokeCount, 450);
        expect(result.dragFactor, 115);
        expect(result.minHeartRate, 120);
        expect(result.maxHeartRate, 175);
        expect(result.endingHeartRate, 168);
        expect(result.timezone, 'America/New_York');
        expect(result.timeSamples, hasLength(2));
        expect(result.timeSamples[0].pace, 1050);
        expect(result.timeSamples[0].distance, 5.2);
        expect(result.timeSamples[1].heartRate, isNull);
      });

      test('defaults for missing C2 detail fields', () {
        final json = resultJson();
        final result = WorkoutResult.fromJson(json);

        expect(result.strokeCount, 0);
        expect(result.dragFactor, isNull);
        expect(result.minHeartRate, isNull);
        expect(result.maxHeartRate, isNull);
        expect(result.endingHeartRate, isNull);
        expect(result.timezone, 'UTC');
        expect(result.timeSamples, isEmpty);
      });

      test('serializes C2 detail fields', () {
        final json = resultJson();
        json['stroke_count'] = 450;
        json['drag_factor'] = 115;
        json['min_heart_rate'] = 120;
        json['max_heart_rate'] = 175;
        json['ending_heart_rate'] = 168;
        json['timezone'] = 'America/New_York';
        json['time_samples'] = [
          {'t': 1000, 'd': 5.2, 'p': 1050, 'spm': 28, 'hr': 145, 'si': 0},
        ];

        final result = WorkoutResult.fromJson(json);
        final output = result.toJson();

        expect(output['stroke_count'], 450);
        expect(output['drag_factor'], 115);
        expect(output['min_heart_rate'], 120);
        expect(output['max_heart_rate'], 175);
        expect(output['ending_heart_rate'], 168);
        expect(output['timezone'], 'America/New_York');
        expect(output['time_samples'], hasLength(1));
      });

      test('omits time_samples when empty', () {
        final json = resultJson();
        final result = WorkoutResult.fromJson(json);
        final output = result.toJson();

        expect(output.containsKey('time_samples'), isFalse);
      });
    });
  });

  group('WorkoutTimeSample', () {
    test('toJson uses compact keys', () {
      const sample = WorkoutTimeSample(
        timestamp: Duration(milliseconds: 5000),
        distance: 25.3,
        pace: 1050,
        strokeRate: 28,
        heartRate: 145,
        segmentIndex: 0,
      );

      final json = sample.toJson();

      expect(json['t'], 5000);
      expect(json['d'], 25.3);
      expect(json['p'], 1050);
      expect(json['spm'], 28);
      expect(json['hr'], 145);
      expect(json['si'], 0);
    });

    test('toJson omits hr when null', () {
      const sample = WorkoutTimeSample(
        timestamp: Duration(milliseconds: 5000),
        distance: 25.3,
        pace: 1050,
        strokeRate: 28,
        segmentIndex: 0,
      );

      final json = sample.toJson();
      expect(json.containsKey('hr'), isFalse);
    });

    test('fromJson/toJson roundtrip', () {
      const original = WorkoutTimeSample(
        timestamp: Duration(milliseconds: 12000),
        distance: 60.5,
        pace: 1100,
        strokeRate: 26,
        heartRate: 155,
        segmentIndex: 2,
      );

      final json = original.toJson();
      final restored = WorkoutTimeSample.fromJson(json);

      expect(restored.timestamp, original.timestamp);
      expect(restored.distance, original.distance);
      expect(restored.pace, original.pace);
      expect(restored.strokeRate, original.strokeRate);
      expect(restored.heartRate, original.heartRate);
      expect(restored.segmentIndex, original.segmentIndex);
    });
  });

  group('SplitData HR min/max', () {
    test('serializes min/max heart rate', () {
      final json = splitJson();
      json['min_heart_rate'] = 130;
      json['max_heart_rate'] = 170;

      final split = SplitData.fromJson(json);
      expect(split.minHeartRate, 130);
      expect(split.maxHeartRate, 170);

      final output = split.toJson();
      expect(output['min_heart_rate'], 130);
      expect(output['max_heart_rate'], 170);
    });

    test('omits min/max heart rate when null', () {
      final json = splitJson();
      final split = SplitData.fromJson(json);
      final output = split.toJson();

      expect(output.containsKey('min_heart_rate'), isFalse);
      expect(output.containsKey('max_heart_rate'), isFalse);
    });
  });
}
