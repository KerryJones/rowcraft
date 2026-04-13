import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_segment.dart';
import 'package:rowcraft/utils/pace_utils.dart';

void main() {
  group('resolveSegmentTargetPace', () {
    test('uses targetWatts when set (ignoring targetIntensity)', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 60,
        targetWatts: 200,
        targetIntensity: 50, // should be ignored
      );
      // 200W should give a pace, and it should match wattsToPaceTenths(200)
      expect(
        resolveSegmentTargetPace(segment, 150),
        wattsToPaceTenths(200),
      );
    });

    test('falls back to targetIntensity when targetWatts is null', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 60,
        targetIntensity: 100,
      );
      // 100% of 150W FTP = 150W
      expect(
        resolveSegmentTargetPace(segment, 150),
        resolveIntensityToPace(100, 150),
      );
    });

    test('returns 0 when no target set', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 60,
      );
      expect(resolveSegmentTargetPace(segment, 150), 0);
    });

    test('targetWatts does not depend on ftpWatts', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 60,
        targetWatts: 200,
      );
      // Same result regardless of FTP
      final pace1 = resolveSegmentTargetPace(segment, 100);
      final pace2 = resolveSegmentTargetPace(segment, 300);
      expect(pace1, pace2);
    });

    test('targetIntensity changes with ftpWatts', () {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 60,
        targetIntensity: 100,
      );
      final pace1 = resolveSegmentTargetPace(segment, 100);
      final pace2 = resolveSegmentTargetPace(segment, 200);
      // Higher FTP = faster pace (lower number)
      expect(pace2, lessThan(pace1));
    });
  });
}
