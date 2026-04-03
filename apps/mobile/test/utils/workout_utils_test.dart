import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_segment.dart';
import 'package:rowcraft/utils/workout_utils.dart';

void main() {
  group('computeTotalTime', () {
    test('returns sum of time-based segments', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300, // 5:00
        ),
        const WorkoutSegment(
          type: SegmentType.rest,
          durationType: DurationType.time,
          durationValue: 60,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
        ),
        const WorkoutSegment(
          type: SegmentType.rest,
          durationType: DurationType.time,
          durationValue: 60,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
        ),
        const WorkoutSegment(
          type: SegmentType.rest,
          durationType: DurationType.time,
          durationValue: 60,
        ),
      ];
      expect(computeTotalTime(segments), 1080); // 900 + 180
    });

    test('returns null for distance-only workout', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.distance,
          durationValue: 2000,
        ),
      ];
      expect(computeTotalTime(segments), isNull);
    });
  });

  group('computeTotalDistance', () {
    test('returns sum of distance-based segments', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.distance,
          durationValue: 500,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.distance,
          durationValue: 500,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.distance,
          durationValue: 500,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.distance,
          durationValue: 500,
        ),
      ];
      expect(computeTotalDistance(segments), 2000);
    });

    test('returns null for time-only workout', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
        ),
      ];
      expect(computeTotalDistance(segments), isNull);
    });
  });

  group('computeSegmentCount', () {
    test('counts individual segments', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.warmup,
          durationType: DurationType.time,
          durationValue: 300,
        ),
        ...List.generate(8, (_) => const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 120,
        )),
        ...List.generate(8, (_) => const WorkoutSegment(
          type: SegmentType.rest,
          durationType: DurationType.time,
          durationValue: 60,
        )),
        const WorkoutSegment(
          type: SegmentType.cooldown,
          durationType: DurationType.time,
          durationValue: 300,
        ),
      ];
      expect(computeSegmentCount(segments), 18); // 1 + 8 + 8 + 1
    });
  });

  group('computeAvgPace', () {
    test('returns weighted average pace of work segments', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1200, max: 1300), // 2:00
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1000, max: 1100), // 1:40
        ),
      ];
      // Equal weight: avg = (1200 + 1000) / 2 = 1100
      expect(computeAvgPace(segments), 1100);
    });

    test('returns null when no pace targets', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
        ),
      ];
      expect(computeAvgPace(segments), isNull);
    });

    test('ignores rest segments', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1200, max: 1300),
        ),
        const WorkoutSegment(
          type: SegmentType.rest,
          durationType: DurationType.time,
          durationValue: 60,
          targetSplit: SplitTarget(min: 2000, max: 2000),
        ),
      ];
      expect(computeAvgPace(segments), 1200);
    });
  });

  group('computeIntensity', () {
    test('returns 1.0 at reference pace (2:00/500m)', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1200, max: 1200),
        ),
      ];
      expect(computeIntensity(segments), 1.0);
    });

    test('returns > 1.0 for faster than reference', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1000, max: 1000), // 1:40/500m
        ),
      ];
      expect(computeIntensity(segments), greaterThan(1.0));
    });

    test('returns < 1.0 for slower than reference', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1500, max: 1500), // 2:30/500m
        ),
      ];
      expect(computeIntensity(segments), lessThan(1.0));
    });

    test('returns null when no pace targets', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
        ),
      ];
      expect(computeIntensity(segments), isNull);
    });

    test('ignores warmup and cooldown segments', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.warmup,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1500, max: 1500), // easy
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1200, max: 1200), // reference
        ),
      ];
      // Only work segment counted → intensity = 1.0
      expect(computeIntensity(segments), 1.0);
    });

    test('returns null when only non-work segments have pace targets', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.warmup,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1500, max: 1500),
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          // no pace target on work segment
        ),
      ];
      expect(computeIntensity(segments), isNull);
    });
  });

  group('computeDifficultyLevel', () {
    test('easy: slower than 2:10/500m', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1400, max: 1400), // 2:20/500m → intensity 0.857
        ),
      ];
      expect(computeDifficultyLevel(segments), 1);
    });

    test('medium: 2:10 to 2:01/500m', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1250, max: 1250), // 2:05/500m → intensity 0.96
        ),
      ];
      expect(computeDifficultyLevel(segments), 2);
    });

    test('hard: 2:00/500m or faster', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1200, max: 1200), // 2:00/500m → intensity 1.0
        ),
      ];
      expect(computeDifficultyLevel(segments), 3);
    });

    test('intensity only considers work segments', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.warmup,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1500, max: 1500), // easy warmup
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1000, max: 1000), // hard work
        ),
        const WorkoutSegment(
          type: SegmentType.cooldown,
          durationType: DurationType.time,
          durationValue: 300,
          targetSplit: SplitTarget(min: 1500, max: 1500), // easy cooldown
        ),
      ];
      // Only the work segment should be considered → hard
      expect(computeDifficultyLevel(segments), 3);
    });

    test('no pace targets: short workout = easy', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 600, // 10 min
        ),
      ];
      expect(computeDifficultyLevel(segments), 1);
    });

    test('no pace targets: long workout = hard', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 3600, // 60 min
        ),
      ];
      expect(computeDifficultyLevel(segments), 3);
    });

    test('complexity bonus: many segments bumps level', () {
      // Easy pace but 12 individual segments → bumps from 1 to 2
      final segments = [
        ...List.generate(6, (_) => const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 60,
          targetSplit: SplitTarget(min: 1400, max: 1400), // ~2:20 → easy
        )),
        ...List.generate(6, (_) => const WorkoutSegment(
          type: SegmentType.rest,
          durationType: DurationType.time,
          durationValue: 30,
        )),
      ];
      expect(computeSegmentCount(segments), 12);
      expect(computeDifficultyLevel(segments), 2); // bumped from 1→2
    });
  });

  group('formatDuration', () {
    test('formats minutes and seconds', () {
      expect(formatDuration(90), '1:30');
      expect(formatDuration(300), '5:00');
      expect(formatDuration(0), '0:00');
    });

    test('formats hours', () {
      expect(formatDuration(3661), '1:01:01');
      expect(formatDuration(7200), '2:00:00');
    });
  });

  group('formatPace', () {
    test('formats tenths to pace string', () {
      expect(formatPace(1200), '2:00');
      expect(formatPace(1345), '2:14');
      expect(formatPace(1000), '1:40');
    });
  });

  group('formatDistance', () {
    test('formats with comma separator for >= 1000', () {
      expect(formatDistance(2000), '2,000m');
      expect(formatDistance(10000), '10,000m');
    });

    test('no comma for < 1000', () {
      expect(formatDistance(500), '500m');
    });
  });
}
