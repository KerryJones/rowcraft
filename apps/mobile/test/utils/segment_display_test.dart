import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/models/workout_segment.dart';
import 'package:rowcraft/utils/pace_utils.dart';
import 'package:rowcraft/utils/segment_display.dart';

void main() {
  group('segmentPaceLabel', () {
    test('work segment with intensity returns formatted pace', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.time,
        durationValue: 300,
        targetIntensity: 85,
      );
      final expectedTenths = intensityToPaceTenths(85, kDefaultFtpWatts);
      final expectedPace = formatPace(expectedTenths);
      expect(segmentPaceLabel(segment, kDefaultFtpWatts), '$expectedPace/500m');
    });

    test('work segment without intensity returns Free', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.time,
        durationValue: 300,
      );
      expect(segmentPaceLabel(segment, kDefaultFtpWatts), 'Free');
    });

    test('rest segment without intensity returns Free', () {
      const segment = WorkoutSegment(
        type: SegmentType.rest,
        durationType: DurationType.time,
        durationValue: 60,
      );
      expect(segmentPaceLabel(segment, kDefaultFtpWatts), 'Free');
    });

    test('warmup segment without intensity returns Free', () {
      const segment = WorkoutSegment(
        type: SegmentType.warmup,
        durationType: DurationType.time,
        durationValue: 120,
      );
      expect(segmentPaceLabel(segment, kDefaultFtpWatts), 'Free');
    });

    test('cooldown segment with intensity returns formatted pace', () {
      const segment = WorkoutSegment(
        type: SegmentType.cooldown,
        durationType: DurationType.time,
        durationValue: 180,
        targetIntensity: 55,
      );
      final expectedTenths = intensityToPaceTenths(55, kDefaultFtpWatts);
      final expectedPace = formatPace(expectedTenths);
      expect(segmentPaceLabel(segment, kDefaultFtpWatts), '$expectedPace/500m');
    });

    test('uses custom FTP watts for pace calculation', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.time,
        durationValue: 300,
        targetIntensity: 100,
      );
      const customFtp = 200;
      final expectedTenths = intensityToPaceTenths(100, customFtp);
      final expectedPace = formatPace(expectedTenths);
      expect(segmentPaceLabel(segment, customFtp), '$expectedPace/500m');
    });
  });

  group('segmentStrokeRateLabel', () {
    test('returns formatted stroke rate when present', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.time,
        durationValue: 300,
        targetStrokeRate: 22,
      );
      expect(segmentStrokeRateLabel(segment), '22 s/m');
    });

    test('returns null when no stroke rate target', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.time,
        durationValue: 300,
      );
      expect(segmentStrokeRateLabel(segment), isNull);
    });

    test('returns exact target as label', () {
      const segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.time,
        durationValue: 300,
        targetStrokeRate: 26,
      );
      expect(segmentStrokeRateLabel(segment), '26 s/m');
    });
  });
}
