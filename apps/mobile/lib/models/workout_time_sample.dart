/// A single time-series data point recorded during a workout.
/// Collected ~1/second for post-workout pace & HR graphs.
class WorkoutTimeSample {
  final Duration timestamp;
  final int pace;
  final int strokeRate;
  final int? heartRate;
  final int segmentIndex;

  const WorkoutTimeSample({
    required this.timestamp,
    required this.pace,
    required this.strokeRate,
    this.heartRate,
    required this.segmentIndex,
  });
}
