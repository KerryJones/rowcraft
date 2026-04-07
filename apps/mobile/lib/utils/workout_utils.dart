import '../models/workout_segment.dart';
import 'pace_utils.dart';


/// Compute total time in seconds for all time-based segments.
/// Returns null if there are no time-based segments.
int? computeTotalTime(List<WorkoutSegment> segments) {
  var total = 0.0;
  var hasTime = false;
  for (final seg in segments) {
    if (seg.durationType == DurationType.time) {
      total += seg.durationValue;
      hasTime = true;
    }
  }
  return hasTime ? total.round() : null;
}

/// Effective duration in seconds for a single segment.
/// Time segments return their value directly. Distance and calorie segments
/// are converted to estimated seconds using target intensity / FTP.
double effectiveDuration(WorkoutSegment seg, int ftpWatts) {
  switch (seg.durationType) {
    case DurationType.time:
      return seg.durationValue;
    case DurationType.distance:
      final double? targetPace;
      if (seg.targetIntensity != null) {
        targetPace = resolveIntensityToPace(
          seg.targetIntensity!,
          ftpWatts,
        ).toDouble();
      } else {
        targetPace = null;
      }
      final pacePerMeter = targetPace != null ? (targetPace / 10) / 500 : 0.24;
      return seg.durationValue * pacePerMeter;
    case DurationType.calories:
      return (seg.durationValue / 15) * 60;
  }
}

/// Compute estimated total time in seconds across all segment types.
/// Uses target intensity + FTP to estimate time for distance/calorie segments.
int computeEstimatedTotalTime(List<WorkoutSegment> segments, int ftpWatts) {
  var total = 0.0;
  for (final seg in segments) {
    total += effectiveDuration(seg, ftpWatts);
  }
  return total.round();
}

/// Compute total distance in meters for all distance-based segments.
/// Returns null if no distance-based segments exist.
double? computeTotalDistance(List<WorkoutSegment> segments) {
  var total = 0.0;
  var hasDist = false;
  for (final seg in segments) {
    if (seg.durationType == DurationType.distance) {
      total += seg.durationValue;
      hasDist = true;
    }
  }
  return hasDist ? total : null;
}

/// Compute total segment count.
int computeSegmentCount(List<WorkoutSegment> segments) {
  return segments.length;
}

/// Compute weighted average target intensity (FTP %) across active segments.
/// Returns null if no segments have intensity targets.
int? computeAvgIntensity(List<WorkoutSegment> segments) {
  final workSegs = segments
      .where((s) => s.targetIntensity != null);
  if (workSegs.isEmpty) return null;
  var totalWeight = 0.0;
  var weightedSum = 0.0;
  for (final s in workSegs) {
    final weight = s.durationValue;
    weightedSum += s.targetIntensity! * weight;
    totalWeight += weight;
  }
  return totalWeight > 0 ? (weightedSum / totalWeight).round() : null;
}

/// Compute workout intensity score (0.00 - 1.00+).
/// Weighted average of segment intensity against 100% FTP reference.
/// Higher = harder. Duration-weighted by segment duration value.
/// Returns null if no segments have intensity targets.
double? computeIntensity(List<WorkoutSegment> segments) {
  final workSegs = segments
      .where((s) => s.targetIntensity != null);
  if (workSegs.isEmpty) return null;
  var totalWeight = 0.0;
  var weightedSum = 0.0;

  for (final s in workSegs) {
    final duration = s.durationValue;
    weightedSum += (s.targetIntensity! / 100.0) * duration;
    totalWeight += duration;
  }

  if (totalWeight == 0) return null;
  return (weightedSum / totalWeight * 100).roundToDouble() / 100;
}

/// Compute difficulty level 1-3 from workout segments.
/// 1 = easy (green), 2 = medium (amber), 3 = hard (red).
int computeDifficultyLevel(List<WorkoutSegment> segments) {
  final intensity = computeIntensity(segments);
  final segCount = computeSegmentCount(segments);

  int level;

  // Thresholds based on FTP %: <75% easy, 75-95% medium, >95% hard
  if (intensity == null) {
    // No intensity targets — derive from duration and complexity
    final totalTime = computeTotalTime(segments);
    final totalDist = computeTotalDistance(segments);

    double estimatedMinutes;
    if (totalTime != null) {
      estimatedMinutes = totalTime / 60.0;
    } else if (totalDist != null) {
      estimatedMinutes = (totalDist / 500.0) * 2.0;
    } else {
      estimatedMinutes = 15;
    }

    if (estimatedMinutes <= 20) {
      level = 1;
    } else if (estimatedMinutes <= 40) {
      level = 2;
    } else {
      level = 3;
    }
  } else if (intensity < 0.75) {
    level = 1; // Easy: below 75% FTP
  } else if (intensity < 0.95) {
    level = 2; // Medium: 75-95% FTP
  } else {
    level = 3; // Hard: 95%+ FTP
  }

  // Bonus: complex workouts (many segments) bump up one level
  if (segCount > 10 && level < 3) {
    level++;
  }

  return level;
}

/// Format total seconds as a human-readable duration string.
/// e.g. 90 → "1:30", 3661 → "1:01:01"
String formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Format pace in tenths to M:SS display.
/// e.g. 1200 → "2:00"
String formatPace(int tenths) {
  final minutes = tenths ~/ 600;
  final secs = (tenths % 600) ~/ 10;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

/// Format distance for display.
/// e.g. 2000.0 → "2,000m", 500.0 → "500m"
String formatDistance(double meters) {
  final m = meters.toInt();
  if (m >= 1000) {
    final str = m.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return '${buf}m';
  }
  return '${m}m';
}
