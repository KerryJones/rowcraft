import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_segment.dart';
import 'package:rowcraft/utils/pace_utils.dart' show kDefaultFtpWatts;
import 'package:rowcraft/utils/workout_utils.dart';

void main() {
  group('effectiveDuration', () {
    test('returns durationValue directly for time segments', () {
      const seg = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.time,
        durationValue: 300,
      );
      expect(effectiveDuration(seg, kDefaultFtpWatts), 300);
    });

    test('estimates time for distance segment with intensity', () {
      const seg = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.distance,
        durationValue: 2000,
        targetIntensity: 85,
      );
      // 85% of 150W = 128W → 1398 tenths → (1398/10)/500 = 0.2796 s/m
      // 2000 * 0.2796 = 559.2
      expect(effectiveDuration(seg, kDefaultFtpWatts), closeTo(559.2, 0.1));
    });

    test('uses fallback pace for distance segment without intensity', () {
      const seg = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.distance,
        durationValue: 2000,
      );
      // Fallback: 0.24 sec/meter → 2000 * 0.24 = 480 sec
      expect(effectiveDuration(seg, kDefaultFtpWatts), 480);
    });

    test('estimates time for calorie segment', () {
      const seg = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.calories,
        durationValue: 150,
      );
      // 150 cal ÷ 15 cal/min × 60 sec = 600 sec
      expect(effectiveDuration(seg, kDefaultFtpWatts), 600);
    });
  });

  group('computeEstimatedTotalTime', () {
    test('sums all segment types', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.calories,
          durationValue: 15, // 15 cal → 60 sec
        ),
      ];
      expect(computeEstimatedTotalTime(segments, kDefaultFtpWatts), 360);
    });

    test('returns 0 for empty segments', () {
      expect(computeEstimatedTotalTime([], kDefaultFtpWatts), 0);
    });
  });

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

  group('computeAvgIntensity', () {
    test('returns weighted average intensity of work segments', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 85,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 95,
        ),
      ];
      // Equal weight: avg = (85 + 95) / 2 = 90
      expect(computeAvgIntensity(segments), 90);
    });

    test('returns null when no intensity targets', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
        ),
      ];
      expect(computeAvgIntensity(segments), isNull);
    });

    test('ignores rest segments', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 85,
        ),
        const WorkoutSegment(
          type: SegmentType.rest,
          durationType: DurationType.time,
          durationValue: 60,
          targetIntensity: 50,
        ),
      ];
      expect(computeAvgIntensity(segments), 85);
    });
  });

  group('computeIntensity', () {
    test('returns 1.0 at 100% FTP', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 100,
        ),
      ];
      expect(computeIntensity(segments), 1.0);
    });

    test('returns > 1.0 for above 100% FTP', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 115,
        ),
      ];
      expect(computeIntensity(segments), greaterThan(1.0));
    });

    test('returns < 1.0 for below 100% FTP', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 65,
        ),
      ];
      expect(computeIntensity(segments), lessThan(1.0));
    });

    test('returns null when no intensity targets', () {
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
          targetIntensity: 55,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 100,
        ),
      ];
      // Only work segment counted → intensity = 1.0
      expect(computeIntensity(segments), 1.0);
    });

    test('returns null when only non-work segments have intensity targets', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.warmup,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 55,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          // no intensity target on work segment
        ),
      ];
      expect(computeIntensity(segments), isNull);
    });
  });

  group('computeDifficultyLevel', () {
    test('easy: below 75% FTP', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 65,
        ),
      ];
      expect(computeDifficultyLevel(segments), 1);
    });

    test('medium: 75-95% FTP', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 85,
        ),
      ];
      expect(computeDifficultyLevel(segments), 2);
    });

    test('hard: 95%+ FTP', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 100,
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
          targetIntensity: 55,
        ),
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 105, // hard work
        ),
        const WorkoutSegment(
          type: SegmentType.cooldown,
          durationType: DurationType.time,
          durationValue: 300,
          targetIntensity: 55,
        ),
      ];
      // Only the work segment should be considered → hard
      expect(computeDifficultyLevel(segments), 3);
    });

    test('no intensity targets: short workout = easy', () {
      final segments = [
        const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 600, // 10 min
        ),
      ];
      expect(computeDifficultyLevel(segments), 1);
    });

    test('no intensity targets: long workout = hard', () {
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
      // Easy intensity but 12 individual segments → bumps from 1 to 2
      final segments = [
        ...List.generate(6, (_) => const WorkoutSegment(
          type: SegmentType.work,
          durationType: DurationType.time,
          durationValue: 60,
          targetIntensity: 65, // easy
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
