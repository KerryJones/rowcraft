import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_segment.dart';

void main() {
  group('DurationType enum', () {
    test('toJson returns the enum name', () {
      expect(DurationType.time.toJson(), 'time');
      expect(DurationType.distance.toJson(), 'distance');
      expect(DurationType.calories.toJson(), 'calories');
    });

    test('fromJson parses the enum name', () {
      expect(DurationType.fromJson('time'), DurationType.time);
      expect(DurationType.fromJson('distance'), DurationType.distance);
      expect(DurationType.fromJson('calories'), DurationType.calories);
    });

    test('fromJson throws on unknown value', () {
      expect(
          () => DurationType.fromJson('reps'), throwsA(isA<StateError>()));
    });
  });

  group('WorkoutSegment.fromJson', () {
    test('deserializes full segment with all targets', () {
      final json = {
        'duration_type': 'distance',
        'duration_value': 1000.0,
        'target_intensity': 80,
        'target_stroke_rate': 28,
        'target_hr_zone': 4,
      };

      final segment = WorkoutSegment.fromJson(json);
      expect(segment.durationType, DurationType.distance);
      expect(segment.durationValue, 1000.0);
      expect(segment.targetIntensity, 80);
      expect(segment.targetStrokeRate, 28);
      expect(segment.targetHrZone, 4);
    });

    test('null targets handled correctly', () {
      final json = {
        'duration_type': 'time',
        'duration_value': 120.0,
      };

      final segment = WorkoutSegment.fromJson(json);
      expect(segment.targetIntensity, isNull);
      expect(segment.targetStrokeRate, isNull);
      expect(segment.targetHrZone, isNull);
    });

    test('durationValue handles int values from JSON', () {
      final json = {
        'duration_type': 'distance',
        'duration_value': 2000,
      };

      final segment = WorkoutSegment.fromJson(json);
      expect(segment.durationValue, 2000.0);
    });

    test('ignores unknown fields like type', () {
      final json = {
        'type': 'work', // legacy field, should be ignored
        'duration_type': 'time',
        'duration_value': 300.0,
        'target_intensity': 85,
      };

      final segment = WorkoutSegment.fromJson(json);
      expect(segment.durationType, DurationType.time);
      expect(segment.targetIntensity, 85);
    });
  });

  group('WorkoutSegment.toJson', () {
    test('serializes full segment', () {
      const segment = WorkoutSegment(
        durationType: DurationType.distance,
        durationValue: 1000.0,
        targetIntensity: 80,
        targetStrokeRate: 28,
        targetHrZone: 4,
      );

      final json = segment.toJson();
      expect(json.containsKey('type'), isFalse);
      expect(json['duration_type'], 'distance');
      expect(json['duration_value'], 1000.0);
      expect(json['target_intensity'], 80);
      expect(json['target_stroke_rate'], 28);
      expect(json['target_hr_zone'], 4);
    });

    test('omits null targets and is_rest=false from JSON', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 120.0,
      );

      final json = segment.toJson();
      expect(json.containsKey('target_intensity'), isFalse);
      expect(json.containsKey('target_stroke_rate'), isFalse);
      expect(json.containsKey('target_hr_zone'), isFalse);
      expect(json.containsKey('is_rest'), isFalse);
    });

    test('includes is_rest: true when explicit rest', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 60.0,
        isRest: true,
      );

      final json = segment.toJson();
      expect(json['is_rest'], isTrue);
    });
  });

  group('fromJson/toJson roundtrip', () {
    test('full segment survives roundtrip', () {
      final original = {
        'duration_type': 'distance',
        'duration_value': 1000.0,
        'target_intensity': 80,
        'target_stroke_rate': 28,
        'target_hr_zone': 4,
      };

      final segment = WorkoutSegment.fromJson(original);
      final json = segment.toJson();

      expect(json['duration_type'], original['duration_type']);
      expect(json['duration_value'], original['duration_value']);
      expect(json['target_intensity'], original['target_intensity']);
      expect(json['target_stroke_rate'], original['target_stroke_rate']);
      expect(json['target_hr_zone'], original['target_hr_zone']);
    });

    test('minimal segment survives roundtrip', () {
      final original = {
        'duration_type': 'time',
        'duration_value': 60.0,
      };

      final segment = WorkoutSegment.fromJson(original);
      final json = segment.toJson();
      final roundtripped = WorkoutSegment.fromJson(json);

      expect(roundtripped.durationType, segment.durationType);
      expect(roundtripped.durationValue, segment.durationValue);
      expect(roundtripped.targetIntensity, isNull);
      expect(roundtripped.targetStrokeRate, isNull);
      expect(roundtripped.targetHrZone, isNull);
    });
  });

  group('isRest', () {
    test('defaults to false (free-row segments with no targets are not rest)', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 60.0,
      );
      expect(segment.isRest, isFalse);
    });

    test('explicit isRest: true marks segment as rest', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 60.0,
        isRest: true,
      );
      expect(segment.isRest, isTrue);
    });

    test('segment with intensity is not rest', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 300.0,
        targetIntensity: 85,
      );
      expect(segment.isRest, isFalse);
    });

    test('segment with stroke rate only is not rest', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 300.0,
        targetStrokeRate: 22,
      );
      expect(segment.isRest, isFalse);
    });
  });

  group('durationLabel', () {
    test('distance type formats as meters', () {
      const segment = WorkoutSegment(
        durationType: DurationType.distance,
        durationValue: 2000.0,
      );
      expect(segment.durationLabel, '2000m');
    });

    test('time type formats as M:SS', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 300.0,
      );
      expect(segment.durationLabel, '5:00');
    });

    test('time type with non-zero seconds formats correctly', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 90.0,
      );
      expect(segment.durationLabel, '1:30');
    });

    test('time type with single-digit seconds pads with zero', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 65.0,
      );
      expect(segment.durationLabel, '1:05');
    });

    test('calories type formats with cal suffix', () {
      const segment = WorkoutSegment(
        durationType: DurationType.calories,
        durationValue: 100.0,
      );
      expect(segment.durationLabel, '100cal');
    });

    test('zero time formats as 0:00', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 0.0,
      );
      expect(segment.durationLabel, '0:00');
    });
  });

  group('WorkoutSegment.copyWith', () {
    test('can set isRest via copyWith', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 60.0,
      );
      expect(segment.copyWith(isRest: true).isRest, isTrue);
      expect(segment.copyWith(isRest: false).isRest, isFalse);
    });

    test('preserves unchanged fields', () {
      const original = WorkoutSegment(
        durationType: DurationType.distance,
        durationValue: 1000.0,
        targetIntensity: 80,
        targetStrokeRate: 28,
        targetHrZone: 4,
      );

      final copied = original.copyWith(durationValue: 500.0);

      expect(copied.durationType, original.durationType);
      expect(copied.durationValue, 500.0);
      expect(copied.targetIntensity, original.targetIntensity);
      expect(copied.targetStrokeRate, original.targetStrokeRate);
      expect(copied.targetHrZone, original.targetHrZone);
    });
  });

  test('toString includes isRest status and durationLabel', () {
    const segment = WorkoutSegment(
      durationType: DurationType.distance,
      durationValue: 1000.0,
      targetIntensity: 85,
    );
    final str = segment.toString();
    expect(str, contains('active'));
    expect(str, contains('1000m'));
  });

  test('toString shows free for segment without targets but isRest=false', () {
    const segment = WorkoutSegment(
      durationType: DurationType.time,
      durationValue: 60.0,
    );
    final str = segment.toString();
    expect(str, contains('free'));
  });

  test('toString shows rest for explicit rest segment', () {
    const segment = WorkoutSegment(
      durationType: DurationType.time,
      durationValue: 60.0,
      isRest: true,
    );
    final str = segment.toString();
    expect(str, contains('rest'));
  });
}
