// Shared formatting helpers for the workout session screens.

import '../../../models/workout_segment.dart';
import '../../../utils/workout_utils.dart';
import '../workout_engine.dart';
import '../workout_provider.dart';

/// Pace acceptance range with 5% tolerance around target pace.
/// Determines color feedback and TOO SLOW / TOO FAST warnings.
(double, double) paceAcceptanceRange(int targetPace) {
  final tolerance = targetPace * 0.05;
  return (targetPace - tolerance, targetPace + tolerance);
}

/// Remaining workout time, formatted M:SS. Sums per-segment effective
/// durations across the unfinished portion of the workout.
String remainingWorkoutLabel(WorkoutSessionState session) {
  final segments = session.expandedSegments;
  if (segments.isEmpty) return '--:--';

  final ftpWatts = session.ftpWatts;
  final durations =
      segments.map((s) => effectiveDuration(s, ftpWatts)).toList();
  final totalDuration = durations.fold<double>(0, (a, b) => a + b);
  if (totalDuration <= 0) return '--:--';

  final currentIndex = session.engineState.currentSegmentIndex;
  var elapsed = 0.0;
  for (var i = 0; i < currentIndex && i < durations.length; i++) {
    elapsed += durations[i];
  }
  if (currentIndex < durations.length) {
    elapsed += session.engineState.segmentProgress * durations[currentIndex];
  }

  final remainingSec =
      ((totalDuration - elapsed).clamp(0, totalDuration)).round();
  final m = remainingSec ~/ 60;
  final s = remainingSec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Remaining label for segment countdown.
/// Returns (value, unitSuffix) so the unit can be styled separately.
(String, String?) remainingSegmentLabel(WorkoutEngineState state) {
  final segment = state.currentSegment;
  if (segment == null) return ('', null);

  switch (segment.durationType) {
    case DurationType.time:
      final totalSec = segment.durationValue.toInt();
      final remaining =
          (totalSec * (1 - state.segmentProgress)).round().clamp(0, totalSec);
      final min = remaining ~/ 60;
      final sec = remaining % 60;
      return ('$min:${sec.toString().padLeft(2, '0')}', null);
    case DurationType.distance:
      final totalM = segment.durationValue;
      final remaining =
          (totalM - state.segmentElapsedDistance).clamp(0.0, totalM).toInt();
      return ('$remaining', 'm');
    case DurationType.calories:
      final totalCal = segment.durationValue;
      final remaining = (totalCal - state.segmentElapsedCalories)
          .clamp(0.0, totalCal)
          .round();
      return ('$remaining', 'cal');
  }
}
