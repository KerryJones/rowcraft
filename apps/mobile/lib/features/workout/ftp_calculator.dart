import '../../models/workout_result.dart';
import '../../models/workout_segment.dart';

/// FTP calculation from ramp and 20-minute test results.
class FtpCalculator {
  FtpCalculator._();

  /// Calculate FTP from a ramp test.
  ///
  /// FTP = 65% of peak watts from the last completed work segment.
  /// The ramp test progressively increases intensity until failure;
  /// the last completed work segment represents peak sustainable output.
  static int calculateRampFtp(
    List<SplitData> splits,
    List<WorkoutSegment> segments,
  ) {
    // Find the peak watts across all work-segment splits
    int peakWatts = 0;
    for (var i = 0; i < splits.length; i++) {
      // Match split to segment if possible
      final segIndex = splits[i].intervalIndex;
      final isWork = segIndex < segments.length &&
          segments[segIndex].type == SegmentType.work;

      // If we can't match segments, count all splits
      if (isWork || segments.isEmpty) {
        if (splits[i].avgWatts > peakWatts) {
          peakWatts = splits[i].avgWatts;
        }
      }
    }

    if (peakWatts == 0) return 0;
    return (peakWatts * 0.65).round();
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
