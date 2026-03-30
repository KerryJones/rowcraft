import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_segment.dart';

void main() {
  group('SegmentType enum', () {
    test('toJson returns the enum name', () {
      expect(SegmentType.work.toJson(), 'work');
      expect(SegmentType.rest.toJson(), 'rest');
      expect(SegmentType.warmup.toJson(), 'warmup');
      expect(SegmentType.cooldown.toJson(), 'cooldown');
    });

    test('fromJson parses the enum name', () {
      expect(SegmentType.fromJson('work'), SegmentType.work);
      expect(SegmentType.fromJson('rest'), SegmentType.rest);
      expect(SegmentType.fromJson('warmup'), SegmentType.warmup);
      expect(SegmentType.fromJson('cooldown'), SegmentType.cooldown);
    });

    test('fromJson throws on unknown value', () {
      expect(
          () => SegmentType.fromJson('sprint'), throwsA(isA<StateError>()));
    });
  });

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

  group('SplitTarget', () {
    test('fromJson/toJson roundtrip', () {
      final json = {'min': 95.0, 'max': 100.0};
      final target = SplitTarget.fromJson(json);
      expect(target.min, 95.0);
      expect(target.max, 100.0);
      expect(target.toJson(), json);
    });

    test('fromJson handles int values by converting to double', () {
      final json = {'min': 90, 'max': 105};
      final target = SplitTarget.fromJson(json);
      expect(target.min, 90.0);
      expect(target.max, 105.0);
    });

    test('copyWith', () {
      const target = SplitTarget(min: 95.0, max: 100.0);
      final copied = target.copyWith(min: 88.0);
      expect(copied.min, 88.0);
      expect(copied.max, 100.0);
    });
  });

  group('StrokeRateTarget', () {
    test('fromJson/toJson roundtrip', () {
      final json = {'min': 26, 'max': 30};
      final target = StrokeRateTarget.fromJson(json);
      expect(target.min, 26);
      expect(target.max, 30);
      expect(target.toJson(), json);
    });

    test('copyWith', () {
      const target = StrokeRateTarget(min: 26, max: 30);
      final copied = target.copyWith(max: 34);
      expect(copied.min, 26);
      expect(copied.max, 34);
    });
  });

  group('WorkoutSegment.fromJson', () {
    test('deserializes full segment with all targets', () {
      final json = {
        'type': 'work',
        'duration_type': 'distance',
        'duration_value': 1000.0,
        'target_split': {'min': 95.0, 'max': 100.0},
        'target_stroke_rate': {'min': 28, 'max': 32},
        'target_hr_zone': 4,
        'repeat': 5,
      };

      final segment = WorkoutSegment.fromJson(json);
      expect(segment.type, SegmentType.work);
      expect(segment.durationType, DurationType.distance);
      expect(segment.durationValue, 1000.0);
      expect(segment.targetSplit, isNotNull);
      expect(segment.targetSplit!.min, 95.0);
      expect(segment.targetSplit!.max, 100.0);
      expect(segment.targetStrokeRate, isNotNull);
      expect(segment.targetStrokeRate!.min, 28);
      expect(segment.targetStrokeRate!.max, 32);
      expect(segment.targetHrZone, 4);
      expect(segment.repeat, 5);
    });

    test('null targets handled correctly', () {
      final json = {
        'type': 'rest',
        'duration_type': 'time',
        'duration_value': 120.0,
        'repeat': 1,
      };

      final segment = WorkoutSegment.fromJson(json);
      expect(segment.targetSplit, isNull);
      expect(segment.targetStrokeRate, isNull);
      expect(segment.targetHrZone, isNull);
    });

    test('repeat defaults to 1 when missing', () {
      final json = {
        'type': 'warmup',
        'duration_type': 'time',
        'duration_value': 300.0,
      };

      final segment = WorkoutSegment.fromJson(json);
      expect(segment.repeat, 1);
    });

    test('durationValue handles int values from JSON', () {
      final json = {
        'type': 'work',
        'duration_type': 'distance',
        'duration_value': 2000,
        'repeat': 1,
      };

      final segment = WorkoutSegment.fromJson(json);
      expect(segment.durationValue, 2000.0);
    });
  });

  group('WorkoutSegment.toJson', () {
    test('serializes full segment', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.distance,
        durationValue: 1000.0,
        targetSplit: SplitTarget(min: 95.0, max: 100.0),
        targetStrokeRate: StrokeRateTarget(min: 28, max: 32),
        targetHrZone: 4,
        repeat: 5,
      );

      final json = segment.toJson();
      expect(json['type'], 'work');
      expect(json['duration_type'], 'distance');
      expect(json['duration_value'], 1000.0);
      expect(json['target_split'], {'min': 95.0, 'max': 100.0});
      expect(json['target_stroke_rate'], {'min': 28, 'max': 32});
      expect(json['target_hr_zone'], 4);
      expect(json['repeat'], 5);
    });

    test('omits null targets from JSON', () {
      const segment = WorkoutSegment(
        type: SegmentType.rest,
        durationType: DurationType.time,
        durationValue: 120.0,
      );

      final json = segment.toJson();
      expect(json.containsKey('target_split'), isFalse);
      expect(json.containsKey('target_stroke_rate'), isFalse);
      expect(json.containsKey('target_hr_zone'), isFalse);
    });
  });

  group('fromJson/toJson roundtrip', () {
    test('full segment survives roundtrip', () {
      final original = {
        'type': 'work',
        'duration_type': 'distance',
        'duration_value': 1000.0,
        'target_split': {'min': 95.0, 'max': 100.0},
        'target_stroke_rate': {'min': 28, 'max': 32},
        'target_hr_zone': 4,
        'repeat': 5,
      };

      final segment = WorkoutSegment.fromJson(original);
      final json = segment.toJson();

      expect(json['type'], original['type']);
      expect(json['duration_type'], original['duration_type']);
      expect(json['duration_value'], original['duration_value']);
      expect(json['target_split'], original['target_split']);
      expect(json['target_stroke_rate'], original['target_stroke_rate']);
      expect(json['target_hr_zone'], original['target_hr_zone']);
      expect(json['repeat'], original['repeat']);
    });

    test('minimal segment survives roundtrip', () {
      final original = {
        'type': 'rest',
        'duration_type': 'time',
        'duration_value': 60.0,
      };

      final segment = WorkoutSegment.fromJson(original);
      final json = segment.toJson();
      final roundtripped = WorkoutSegment.fromJson(json);

      expect(roundtripped.type, segment.type);
      expect(roundtripped.durationType, segment.durationType);
      expect(roundtripped.durationValue, segment.durationValue);
      expect(roundtripped.targetSplit, isNull);
      expect(roundtripped.targetStrokeRate, isNull);
      expect(roundtripped.targetHrZone, isNull);
      expect(roundtripped.repeat, 1);
    });
  });

  group('durationLabel', () {
    test('distance type formats as meters', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.distance,
        durationValue: 2000.0,
      );
      expect(segment.durationLabel, '2000m');
    });

    test('time type formats as M:SS', () {
      const segment = WorkoutSegment(
        type: SegmentType.warmup,
        durationType: DurationType.time,
        durationValue: 300.0,
      );
      expect(segment.durationLabel, '5:00');
    });

    test('time type with non-zero seconds formats correctly', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.time,
        durationValue: 90.0,
      );
      expect(segment.durationLabel, '1:30');
    });

    test('time type with single-digit seconds pads with zero', () {
      const segment = WorkoutSegment(
        type: SegmentType.rest,
        durationType: DurationType.time,
        durationValue: 65.0,
      );
      expect(segment.durationLabel, '1:05');
    });

    test('calories type formats with cal suffix', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.calories,
        durationValue: 100.0,
      );
      expect(segment.durationLabel, '100cal');
    });

    test('zero time formats as 0:00', () {
      const segment = WorkoutSegment(
        type: SegmentType.rest,
        durationType: DurationType.time,
        durationValue: 0.0,
      );
      expect(segment.durationLabel, '0:00');
    });
  });

  group('WorkoutSegment.copyWith', () {
    test('preserves unchanged fields', () {
      const original = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.distance,
        durationValue: 1000.0,
        targetSplit: SplitTarget(min: 95.0, max: 100.0),
        targetStrokeRate: StrokeRateTarget(min: 28, max: 32),
        targetHrZone: 4,
        repeat: 5,
      );

      final copied = original.copyWith(durationValue: 500.0);

      expect(copied.type, original.type);
      expect(copied.durationType, original.durationType);
      expect(copied.durationValue, 500.0);
      expect(copied.targetSplit!.min, original.targetSplit!.min);
      expect(copied.targetStrokeRate!.min, original.targetStrokeRate!.min);
      expect(copied.targetHrZone, original.targetHrZone);
      expect(copied.repeat, original.repeat);
    });
  });

  test('toString includes type, durationLabel, and repeat', () {
    const segment = WorkoutSegment(
      type: SegmentType.work,
      durationType: DurationType.distance,
      durationValue: 1000.0,
      repeat: 5,
    );
    final str = segment.toString();
    expect(str, contains('work'));
    expect(str, contains('1000m'));
    expect(str, contains('5'));
  });
}
