import '../models/workout_segment.dart';

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

/// Compute weighted average pace (in tenths per 500m) across work segments with pace targets.
/// Returns null if no work segments have pace targets.
int? computeAvgPace(List<WorkoutSegment> segments) {
  final workSegs = segments
      .where((s) => s.type == SegmentType.work && s.targetSplit != null);
  if (workSegs.isEmpty) return null;
  var totalWeight = 0.0;
  var weightedSum = 0.0;
  for (final s in workSegs) {
    final weight = s.durationValue;
    weightedSum += s.targetSplit!.min * weight;
    totalWeight += weight;
  }
  return totalWeight > 0 ? (weightedSum / totalWeight).round() : null;
}

/// Compute workout intensity score (0.00 - 1.00+).
/// Weighted average of segment pace against a 2:00/500m (1200 tenths) reference.
/// Higher = harder. Duration-weighted by segment duration value.
/// Returns null if no segments have pace targets.
double? computeIntensity(List<WorkoutSegment> segments) {
  const referencePace = 1200.0; // 2:00/500m in tenths
  var totalWeight = 0.0;
  var weightedSum = 0.0;

  for (final seg in segments) {
    if (seg.targetSplit == null) continue;
    if (seg.type != SegmentType.work) continue; // Only work segments count
    final duration = seg.durationValue;
    // Invert: faster pace (lower number) = higher intensity
    final intensity = referencePace / seg.targetSplit!.min;
    weightedSum += intensity * duration;
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

  // Thresholds: easy = slower than 2:10, medium = 2:10–2:01, hard = 2:00 or faster
  // intensity = 1200 / pace_tenths, so 2:10 (1300t) → 0.923, 2:00 (1200t) → 1.0
  if (intensity == null) {
    // No pace targets — derive from duration and complexity
    final totalTime = computeTotalTime(segments);
    final totalDist = computeTotalDistance(segments);

    // Estimate total duration in minutes
    double estimatedMinutes;
    if (totalTime != null) {
      estimatedMinutes = totalTime / 60.0;
    } else if (totalDist != null) {
      // Assume ~2:00/500m pace for estimation
      estimatedMinutes = (totalDist / 500.0) * 2.0;
    } else {
      estimatedMinutes = 15; // Default guess for calorie-based
    }

    if (estimatedMinutes <= 20) {
      level = 1;
    } else if (estimatedMinutes <= 40) {
      level = 2;
    } else {
      level = 3;
    }
  } else if (intensity < 0.923) {
    level = 1; // Easy: slower than 2:10/500m
  } else if (intensity < 1.0) {
    level = 2; // Medium: 2:10 to 2:01/500m
  } else {
    level = 3; // Hard: 2:00/500m or faster
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
