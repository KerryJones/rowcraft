import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout.dart';
import 'package:rowcraft/models/workout_segment.dart';

void main() {
  final now = DateTime.utc(2025, 6, 15, 10, 30, 0);
  final later = DateTime.utc(2025, 6, 15, 11, 0, 0);

  Map<String, dynamic> realisticJson() => {
        'id': 'wk-abc-123',
        'author_id': 'user-xyz-789',
        'title': '5x1000m Intervals',
        'description': 'Hard interval session with 2 min rest',
        'workout_type': 'intervals',
        'segments': [
          {
            'type': 'warmup',
            'duration_type': 'time',
            'duration_value': 300.0,
            'repeat': 1,
          },
          {
            'type': 'work',
            'duration_type': 'distance',
            'duration_value': 1000.0,
            'target_split': {'min': 95.0, 'max': 100.0},
            'target_stroke_rate': {'min': 28, 'max': 32},
            'repeat': 5,
          },
          {
            'type': 'rest',
            'duration_type': 'time',
            'duration_value': 120.0,
            'repeat': 5,
          },
          {
            'type': 'cooldown',
            'duration_type': 'time',
            'duration_value': 300.0,
            'repeat': 1,
          },
        ],
        'tags': ['intervals', 'hard', '1000m'],
        'is_public': true,
        'fork_count': 7,
        'created_at': now.toIso8601String(),
        'updated_at': later.toIso8601String(),
      };

  Workout makeWorkout({
    String id = 'wk-abc-123',
    String authorId = 'user-xyz-789',
    String title = '5x1000m Intervals',
    String description = 'Hard interval session with 2 min rest',
    WorkoutType workoutType = WorkoutType.intervals,
    List<WorkoutSegment>? segments,
    List<String> tags = const ['intervals', 'hard', '1000m'],
    bool isPublic = true,
    int forkCount = 7,
  }) {
    return Workout(
      id: id,
      authorId: authorId,
      title: title,
      description: description,
      workoutType: workoutType,
      segments: segments ?? const [],
      tags: tags,
      isPublic: isPublic,
      forkCount: forkCount,
      createdAt: now,
      updatedAt: later,
    );
  }

  group('WorkoutType enum', () {
    test('toJson returns snake_case matching DB convention', () {
      expect(WorkoutType.singleDistance.toJson(), 'single_distance');
      expect(WorkoutType.singleTime.toJson(), 'single_time');
      expect(WorkoutType.intervals.toJson(), 'intervals');
      expect(WorkoutType.variableIntervals.toJson(), 'variable_intervals');
    });

    test('fromJson parses snake_case values', () {
      expect(WorkoutType.fromJson('single_distance'),
          WorkoutType.singleDistance);
      expect(
          WorkoutType.fromJson('single_time'), WorkoutType.singleTime);
      expect(WorkoutType.fromJson('intervals'), WorkoutType.intervals);
      expect(WorkoutType.fromJson('variable_intervals'),
          WorkoutType.variableIntervals);
    });

    test('fromJson falls back to camelCase for legacy data', () {
      expect(WorkoutType.fromJson('singleDistance'),
          WorkoutType.singleDistance);
      expect(
          WorkoutType.fromJson('singleTime'), WorkoutType.singleTime);
    });

    test('fromJson falls back to intervals for unknown value', () {
      expect(WorkoutType.fromJson('unknown'), WorkoutType.intervals);
    });
  });

  group('Workout.fromJson', () {
    test('deserializes all fields from a realistic JSON object', () {
      final json = realisticJson();
      final workout = Workout.fromJson(json);

      expect(workout.id, 'wk-abc-123');
      expect(workout.authorId, 'user-xyz-789');
      expect(workout.title, '5x1000m Intervals');
      expect(workout.description, 'Hard interval session with 2 min rest');
      expect(workout.workoutType, WorkoutType.intervals);
      expect(workout.segments, hasLength(4));
      expect(workout.segments[0].type, SegmentType.warmup);
      expect(workout.segments[1].type, SegmentType.work);
      expect(workout.segments[1].repeat, 5);
      expect(workout.segments[1].targetSplit, isNotNull);
      expect(workout.segments[1].targetSplit!.min, 95.0);
      expect(workout.segments[2].type, SegmentType.rest);
      expect(workout.segments[3].type, SegmentType.cooldown);
      expect(workout.tags, ['intervals', 'hard', '1000m']);
      expect(workout.isPublic, true);
      expect(workout.forkCount, 7);
      expect(workout.createdAt, now);
      expect(workout.updatedAt, later);
    });

    test('handles empty segments list', () {
      final json = realisticJson();
      json['segments'] = <dynamic>[];
      final workout = Workout.fromJson(json);
      expect(workout.segments, isEmpty);
    });

    test('handles null segments list', () {
      final json = realisticJson();
      json.remove('segments');
      final workout = Workout.fromJson(json);
      expect(workout.segments, isEmpty);
    });

    test('handles missing optional fields with defaults', () {
      final json = realisticJson();
      json.remove('description');
      json.remove('tags');
      json.remove('is_public');
      json.remove('fork_count');
      json.remove('segments');

      final workout = Workout.fromJson(json);
      expect(workout.description, '');
      expect(workout.tags, isEmpty);
      expect(workout.isPublic, false);
      expect(workout.forkCount, 0);
      expect(workout.segments, isEmpty);
    });
  });

  group('Workout.toJson', () {
    test('serializes all fields', () {
      final workout = makeWorkout();
      final json = workout.toJson();

      expect(json['id'], 'wk-abc-123');
      expect(json['author_id'], 'user-xyz-789');
      expect(json['title'], '5x1000m Intervals');
      expect(json['description'], 'Hard interval session with 2 min rest');
      expect(json['workout_type'], 'intervals');
      expect(json['segments'], isA<List>());
      expect(json['tags'], ['intervals', 'hard', '1000m']);
      expect(json['is_public'], true);
      expect(json['fork_count'], 7);
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], later.toIso8601String());
    });

    test('serializes empty segments list', () {
      final workout = makeWorkout(segments: []);
      final json = workout.toJson();
      expect(json['segments'], isEmpty);
    });
  });

  group('fromJson/toJson roundtrip', () {
    test('realistic workout survives roundtrip', () {
      final original = realisticJson();
      final workout = Workout.fromJson(original);
      final roundtripped = Workout.fromJson(workout.toJson());

      expect(roundtripped.id, workout.id);
      expect(roundtripped.authorId, workout.authorId);
      expect(roundtripped.title, workout.title);
      expect(roundtripped.description, workout.description);
      expect(roundtripped.workoutType, workout.workoutType);
      expect(roundtripped.segments.length, workout.segments.length);
      expect(roundtripped.tags, workout.tags);
      expect(roundtripped.isPublic, workout.isPublic);
      expect(roundtripped.forkCount, workout.forkCount);
      expect(roundtripped.createdAt, workout.createdAt);
      expect(roundtripped.updatedAt, workout.updatedAt);
    });

    test('empty segments roundtrip', () {
      final json = realisticJson();
      json['segments'] = <dynamic>[];
      final workout = Workout.fromJson(json);
      final roundtripped = Workout.fromJson(workout.toJson());
      expect(roundtripped.segments, isEmpty);
    });
  });

  group('Workout.copyWith', () {
    test('preserves unchanged fields', () {
      final workout = makeWorkout();
      final copied = workout.copyWith(title: 'New Title');

      expect(copied.id, workout.id);
      expect(copied.authorId, workout.authorId);
      expect(copied.title, 'New Title');
      expect(copied.description, workout.description);
      expect(copied.workoutType, workout.workoutType);
      expect(copied.tags, workout.tags);
      expect(copied.isPublic, workout.isPublic);
      expect(copied.forkCount, workout.forkCount);
      expect(copied.createdAt, workout.createdAt);
      expect(copied.updatedAt, workout.updatedAt);
    });

    test('can change multiple fields at once', () {
      final workout = makeWorkout();
      final copied = workout.copyWith(
        title: 'Changed',
        isPublic: false,
        forkCount: 99,
        workoutType: WorkoutType.singleDistance,
      );

      expect(copied.title, 'Changed');
      expect(copied.isPublic, false);
      expect(copied.forkCount, 99);
      expect(copied.workoutType, WorkoutType.singleDistance);
      // unchanged
      expect(copied.id, workout.id);
      expect(copied.authorId, workout.authorId);
    });

    test('copyWith with no arguments returns equivalent workout', () {
      final workout = makeWorkout();
      final copied = workout.copyWith();

      expect(copied.id, workout.id);
      expect(copied.title, workout.title);
      expect(copied == workout, isTrue);
    });
  });

  group('Workout equality', () {
    test('workouts with same id are equal', () {
      final a = makeWorkout(id: 'same-id');
      final b = makeWorkout(id: 'same-id', title: 'Different Title');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('workouts with different ids are not equal', () {
      final a = makeWorkout(id: 'id-1');
      final b = makeWorkout(id: 'id-2');
      expect(a, isNot(equals(b)));
    });
  });

  test('toString includes id, title, and type', () {
    final workout = makeWorkout();
    final str = workout.toString();
    expect(str, contains('wk-abc-123'));
    expect(str, contains('5x1000m Intervals'));
    expect(str, contains('intervals'));
  });
}
