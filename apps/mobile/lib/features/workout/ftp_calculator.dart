import '../../models/workout_result.dart';
import '../../models/workout_segment.dart';

/// FTP calculation from ramp and 20-minute test results.
class FtpCalculator {
  FtpCalculator._();

  /// Calculate FTP from a ramp test.
  ///
  /// FTP = 65% of the last completed work stage's target watts.
  /// The ramp test uses fixed 20W increments; we use the stage target
  /// (not measured watts) per the standard protocol.
  ///
  /// Work stages are 60-second segments. The 120-second warmup is excluded
  /// from both [stagesCompleted] and [lastStageWatts].
  ///
  /// Returns `(ftpWatts, lastStageWatts, stagesCompleted)`.
  static ({int ftp, int lastStageWatts, int stagesCompleted}) calculateRampFtp(
    List<SplitData> splits,
    List<WorkoutSegment> segments,
  ) {
    int lastStageWatts = 0;
    int stagesCompleted = 0;

    for (var i = 0; i < splits.length; i++) {
      final segIndex = splits[i].intervalIndex;
      if (segIndex >= segments.length) continue;
      final seg = segments[segIndex];

      // Skip warmup (120s) — only count 60s work stages.
      if (seg.durationValue > 60) continue;

      if (seg.targetWatts != null) {
        // Fixed-watt protocol: use the target watts directly
        lastStageWatts = seg.targetWatts!;
        stagesCompleted++;
      } else if (seg.targetIntensity != null) {
        // Legacy fallback: use measured watts from split
        if (splits[i].avgWatts > lastStageWatts) {
          lastStageWatts = splits[i].avgWatts;
        }
        stagesCompleted++;
      }
    }

    if (lastStageWatts == 0) {
      return (ftp: 0, lastStageWatts: 0, stagesCompleted: 0);
    }
    return (
      ftp: (lastStageWatts * 0.65).round(),
      lastStageWatts: lastStageWatts,
      stagesCompleted: stagesCompleted,
    );
  }

  /// Calculate FTP from a 20-minute test.
  ///
  /// FTP = 95% of duration-weighted average watts across work splits.
  /// Weighting by duration ensures short first/last splits don't
  /// distort the result.
  static int calculate20MinFtp(List<SplitData> splits) {
    if (splits.isEmpty) return 0;

    double weightedWattsSum = 0;
    double totalDurationMs = 0;
    for (final split in splits) {
      if (split.avgWatts > 0) {
        final durationMs = split.time.inMilliseconds.toDouble();
        weightedWattsSum += split.avgWatts * durationMs;
        totalDurationMs += durationMs;
      }
    }

    if (totalDurationMs == 0) return 0;
    final avgWatts = weightedWattsSum / totalDurationMs;
    return (avgWatts * 0.95).round();
  }
}
