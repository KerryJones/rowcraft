import '../models/workout_segment.dart';
import 'pace_utils.dart';

/// Returns the target pace label for a segment, e.g. "2:19/500m" or "Free row".
String segmentPaceLabel(WorkoutSegment segment, int ftpWatts) {
  final intensity = segment.targetIntensity;
  if (intensity == null) return segment.isRest ? 'Rest' : 'Free row';
  final tenths = intensityToPaceTenths(intensity, ftpWatts);
  return '${formatPace(tenths)}/500m';
}

/// Returns the stroke rate label for a segment, e.g. "22 s/m", or null.
String? segmentStrokeRateLabel(WorkoutSegment segment) {
  final sr = segment.targetStrokeRate;
  if (sr == null) return null;
  return '$sr s/m';
}
