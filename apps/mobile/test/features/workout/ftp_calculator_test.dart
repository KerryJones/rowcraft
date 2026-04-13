import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/features/workout/ftp_calculator.dart';
import 'package:rowcraft/models/workout_result.dart';
import 'package:rowcraft/models/workout_segment.dart';

void main() {
  group('FtpCalculator.calculateRampFtp', () {
    test('uses last completed stage targetWatts at 65%', () {
      // Ramp test: warmup at 60W, then 60, 80, 100, 120, 140, 160W stages
      final segments = [
        const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 120,
            targetWatts: 60), // warmup
        const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 60,
            targetWatts: 60),
        const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 60,
            targetWatts: 80),
        const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 60,
            targetWatts: 100),
        const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 60,
            targetWatts: 120),
        const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 60,
            targetWatts: 140),
        const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 60,
            targetWatts: 160),
      ];

      // User completed warmup + 5 work stages (through 140W)
      final splits = List.generate(6, (i) => SplitData(
            intervalIndex: i,
            distance: 200,
            time: const Duration(seconds: 60),
            avgPace: 1400,
            avgStrokeRate: 24,
            avgWatts: [60, 60, 80, 100, 120, 140][i],
            avgHeartRate: 150,
            calories: 10,
          ));

      final result =
          FtpCalculator.calculateRampFtp(splits, segments);

      // 65% of 140W = 91W. Warmup (120s) excluded from stage count.
      expect(result.ftp, 91);
      expect(result.lastStageWatts, 140);
      expect(result.stagesCompleted, 5);
    });

    test('returns zero when no splits', () {
      final result = FtpCalculator.calculateRampFtp([], []);
      expect(result.ftp, 0);
      expect(result.lastStageWatts, 0);
      expect(result.stagesCompleted, 0);
    });

    test('uses 65% of last stage for realistic 260W peak', () {
      // Simulating user reaching 260W (like the EXR example)
      final segments = List.generate(
        12,
        (i) => WorkoutSegment(
          durationType: DurationType.time,
          durationValue: 60,
          targetWatts: 40 + i * 20, // 40, 60, 80, ... 260
        ),
      );

      final splits = List.generate(
        12,
        (i) => SplitData(
          intervalIndex: i,
          distance: 200,
          time: const Duration(seconds: 60),
          avgPace: 1400,
          avgStrokeRate: 24,
          avgWatts: 40 + i * 20,
          avgHeartRate: 150,
          calories: 10,
        ),
      );

      final result = FtpCalculator.calculateRampFtp(splits, segments);

      // 65% of 260W = 169W
      expect(result.ftp, 169);
      expect(result.lastStageWatts, 260);
    });
  });

  group('FtpCalculator.calculate20MinFtp', () {
    test('returns 95% of duration-weighted average watts', () {
      final splits = [
        SplitData(
          intervalIndex: 0,
          distance: 2000,
          time: const Duration(minutes: 10),
          avgPace: 1200,
          avgStrokeRate: 26,
          avgWatts: 200,
          avgHeartRate: 165,
          calories: 100,
        ),
        SplitData(
          intervalIndex: 1,
          distance: 2000,
          time: const Duration(minutes: 10),
          avgPace: 1200,
          avgStrokeRate: 26,
          avgWatts: 200,
          avgHeartRate: 170,
          calories: 100,
        ),
      ];

      // 95% of 200W = 190W
      expect(FtpCalculator.calculate20MinFtp(splits), 190);
    });

    test('returns zero for empty splits', () {
      expect(FtpCalculator.calculate20MinFtp([]), 0);
    });

    test('weights by duration', () {
      final splits = [
        SplitData(
          intervalIndex: 0,
          distance: 1000,
          time: const Duration(minutes: 5),
          avgPace: 1200,
          avgStrokeRate: 26,
          avgWatts: 100, // low watts, short duration
          avgHeartRate: 140,
          calories: 50,
        ),
        SplitData(
          intervalIndex: 1,
          distance: 3000,
          time: const Duration(minutes: 15),
          avgPace: 1200,
          avgStrokeRate: 28,
          avgWatts: 200, // high watts, long duration
          avgHeartRate: 170,
          calories: 150,
        ),
      ];

      // Weighted avg: (100*300000 + 200*900000) / (300000+900000) = 175W
      // 95% of 175 = 166.25 → 166
      expect(FtpCalculator.calculate20MinFtp(splits), 166);
    });
  });
}
