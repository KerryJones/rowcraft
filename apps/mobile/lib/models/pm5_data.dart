import '../utils/pace_utils.dart' show formatPace;

/// Real-time data received from a Concept2 PM5 via BLE.
///
/// Pace is in tenths of seconds per 500m (e.g. 1050 = 1:45/500m).
class PM5Data {
  final Duration elapsedTime;
  final double distance;
  final int pace;
  final int strokeRate;
  final int watts;
  final int calories;
  final int? heartRate;
  final int strokeCount;
  final int intervalCount;
  final int dragFactor;

  /// True when strokeRate was freshly parsed from Additional Status 1,
  /// false when copied from a previous snapshot by other characteristics.
  final bool strokeRateUpdated;

  const PM5Data({
    required this.elapsedTime,
    required this.distance,
    required this.pace,
    required this.strokeRate,
    required this.watts,
    required this.calories,
    this.heartRate,
    required this.strokeCount,
    required this.intervalCount,
    this.dragFactor = 0,
    this.strokeRateUpdated = false,
  });

  /// An empty/zero data snapshot, used as initial state.
  const PM5Data.zero()
      : elapsedTime = Duration.zero,
        distance = 0,
        pace = 0,
        strokeRate = 0,
        watts = 0,
        calories = 0,
        heartRate = null,
        strokeCount = 0,
        intervalCount = 0,
        dragFactor = 0,
        strokeRateUpdated = false;

  PM5Data copyWith({
    Duration? elapsedTime,
    double? distance,
    int? pace,
    int? strokeRate,
    int? watts,
    int? calories,
    int? heartRate,
    int? strokeCount,
    int? intervalCount,
    int? dragFactor,
    bool? strokeRateUpdated,
  }) {
    return PM5Data(
      elapsedTime: elapsedTime ?? this.elapsedTime,
      distance: distance ?? this.distance,
      pace: pace ?? this.pace,
      strokeRate: strokeRate ?? this.strokeRate,
      watts: watts ?? this.watts,
      calories: calories ?? this.calories,
      heartRate: heartRate ?? this.heartRate,
      strokeCount: strokeCount ?? this.strokeCount,
      intervalCount: intervalCount ?? this.intervalCount,
      dragFactor: dragFactor ?? this.dragFactor,
      strokeRateUpdated: strokeRateUpdated ?? this.strokeRateUpdated,
    );
  }

  String get paceFormatted => formatPace(pace);

  /// Format elapsed time as H:MM:SS or MM:SS
  String get elapsedFormatted {
    final hours = elapsedTime.inHours;
    final minutes = elapsedTime.inMinutes % 60;
    final seconds = elapsedTime.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format distance — always in meters (no km conversion).
  String get distanceFormatted => '${distance.toInt()}m';

  @override
  String toString() =>
      'PM5Data(elapsed: $elapsedFormatted, dist: ${distance.toInt()}m, '
      'pace: $paceFormatted, sr: $strokeRate, watts: $watts)';
}
