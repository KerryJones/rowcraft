/// A single time-series data point recorded during a workout.
/// Collected ~1/second for post-workout pace & HR graphs and C2 stroke data.
class WorkoutTimeSample {
  final Duration timestamp;
  final double distance;
  final int pace;
  final int strokeRate;
  final int? heartRate;
  final int segmentIndex;

  const WorkoutTimeSample({
    required this.timestamp,
    required this.distance,
    required this.pace,
    required this.strokeRate,
    this.heartRate,
    required this.segmentIndex,
  });

  /// Compact JSON for DB storage. Keys kept short to minimize JSONB size.
  Map<String, dynamic> toJson() => {
        't': timestamp.inMilliseconds,
        'd': distance,
        'p': pace,
        'spm': strokeRate,
        if (heartRate != null) 'hr': heartRate,
        'si': segmentIndex,
      };

  factory WorkoutTimeSample.fromJson(Map<String, dynamic> json) {
    return WorkoutTimeSample(
      timestamp: Duration(milliseconds: json['t'] as int),
      distance: (json['d'] as num).toDouble(),
      pace: json['p'] as int,
      strokeRate: json['spm'] as int,
      heartRate: json['hr'] as int?,
      segmentIndex: json['si'] as int,
    );
  }
}
