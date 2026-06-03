import 'workout_time_sample.dart';

class SplitData {
  final int intervalIndex;
  final double distance;
  final Duration time;
  final int avgPace;
  final int avgStrokeRate;
  final int avgWatts;
  final int? avgHeartRate;
  final int? minHeartRate;
  final int? maxHeartRate;
  final int? endingHeartRate;
  final int calories;
  final bool isRest;

  const SplitData({
    required this.intervalIndex,
    required this.distance,
    required this.time,
    required this.avgPace,
    required this.avgStrokeRate,
    required this.avgWatts,
    this.avgHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.endingHeartRate,
    required this.calories,
    this.isRest = false,
  });

  factory SplitData.fromJson(Map<String, dynamic> json) {
    return SplitData(
      intervalIndex: json['segment_index'] as int,
      distance: (json['distance'] as num).toDouble(),
      time: Duration(milliseconds: json['time_ms'] as int),
      avgPace: json['avg_pace'] as int,
      avgStrokeRate: json['avg_stroke_rate'] as int,
      avgWatts: json['avg_watts'] as int,
      avgHeartRate: json['avg_heart_rate'] as int?,
      minHeartRate: json['min_heart_rate'] as int?,
      maxHeartRate: json['max_heart_rate'] as int?,
      endingHeartRate: json['ending_heart_rate'] as int?,
      calories: json['calories'] as int,
      isRest: (json['is_rest'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'segment_index': intervalIndex,
      'distance': distance,
      'time_ms': time.inMilliseconds,
      'avg_pace': avgPace,
      'avg_stroke_rate': avgStrokeRate,
      'avg_watts': avgWatts,
      if (avgHeartRate != null) 'avg_heart_rate': avgHeartRate,
      if (minHeartRate != null) 'min_heart_rate': minHeartRate,
      if (maxHeartRate != null) 'max_heart_rate': maxHeartRate,
      if (endingHeartRate != null) 'ending_heart_rate': endingHeartRate,
      'calories': calories,
      if (isRest) 'is_rest': true,
    };
  }

  /// Format pace as M:SS (e.g. 1:45)
  String get paceFormatted {
    final minutes = avgPace ~/ 600;
    final remaining = avgPace % 600;
    final seconds = remaining ~/ 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class WorkoutResult {
  final String id;
  final String userId;
  final String? workoutId;
  final String? workoutName;
  final DateTime startedAt;
  final DateTime finishedAt;
  final double totalDistance;
  final Duration totalTime;
  final int avgSplit;
  final int avgStrokeRate;
  final int? avgHeartRate;
  final int? minHeartRate;
  final int? maxHeartRate;
  final int? endingHeartRate;
  final int avgWatts;
  final int calories;
  final int strokeCount;
  final int? dragFactor;
  final String timezone;
  final List<SplitData> splits;
  final List<WorkoutTimeSample> timeSamples;
  final bool syncedToC2;

  const WorkoutResult({
    required this.id,
    required this.userId,
    this.workoutId,
    this.workoutName,
    required this.startedAt,
    required this.finishedAt,
    required this.totalDistance,
    required this.totalTime,
    required this.avgSplit,
    required this.avgStrokeRate,
    this.avgHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.endingHeartRate,
    required this.avgWatts,
    required this.calories,
    this.strokeCount = 0,
    this.dragFactor,
    this.timezone = 'UTC',
    this.splits = const [],
    this.timeSamples = const [],
    this.syncedToC2 = false,
  });

  WorkoutResult copyWith({
    String? id,
    String? userId,
    String? workoutId,
    String? workoutName,
    DateTime? startedAt,
    DateTime? finishedAt,
    double? totalDistance,
    Duration? totalTime,
    int? avgSplit,
    int? avgStrokeRate,
    int? avgHeartRate,
    int? minHeartRate,
    int? maxHeartRate,
    int? endingHeartRate,
    int? avgWatts,
    int? calories,
    int? strokeCount,
    int? dragFactor,
    String? timezone,
    List<SplitData>? splits,
    List<WorkoutTimeSample>? timeSamples,
    bool? syncedToC2,
  }) {
    return WorkoutResult(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workoutId: workoutId ?? this.workoutId,
      workoutName: workoutName ?? this.workoutName,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTime: totalTime ?? this.totalTime,
      avgSplit: avgSplit ?? this.avgSplit,
      avgStrokeRate: avgStrokeRate ?? this.avgStrokeRate,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      endingHeartRate: endingHeartRate ?? this.endingHeartRate,
      avgWatts: avgWatts ?? this.avgWatts,
      calories: calories ?? this.calories,
      strokeCount: strokeCount ?? this.strokeCount,
      dragFactor: dragFactor ?? this.dragFactor,
      timezone: timezone ?? this.timezone,
      splits: splits ?? this.splits,
      timeSamples: timeSamples ?? this.timeSamples,
      syncedToC2: syncedToC2 ?? this.syncedToC2,
    );
  }

  /// Display name: actual workout name, or a generic fallback.
  String get displayName =>
      workoutName ?? (workoutId != null ? 'Structured Workout' : 'Free Row');

  /// Format average split as M:SS
  String get avgSplitFormatted {
    final minutes = avgSplit ~/ 600;
    final remaining = avgSplit % 600;
    final seconds = remaining ~/ 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format total time as H:MM:SS
  String get totalTimeFormatted {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;
    final seconds = totalTime.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory WorkoutResult.fromJson(Map<String, dynamic> json) {
    // Handle both 'total_time' (DB, tenths of seconds) and 'total_time_ms' (legacy)
    final totalTimeValue = json['total_time'] ?? json['total_time_ms'];
    final Duration totalTimeDuration;
    if (totalTimeValue == null) {
      totalTimeDuration = Duration.zero;
    } else if (json.containsKey('total_time')) {
      // DB format: tenths of seconds
      totalTimeDuration = Duration(milliseconds: (totalTimeValue as int) * 100);
    } else {
      // Legacy format: milliseconds
      totalTimeDuration = Duration(milliseconds: totalTimeValue as int);
    }

    return WorkoutResult(
      id: (json['id'] as String?) ?? '',
      userId: json['user_id'] as String,
      workoutId: json['workout_id'] as String?,
      workoutName: (json['workout_name'] as String?) ??
          (json['workouts'] as Map<String, dynamic>?)?['title'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: DateTime.parse(json['finished_at'] as String),
      totalDistance: (json['total_distance'] as num).toDouble(),
      totalTime: totalTimeDuration,
      avgSplit: json['avg_split'] as int,
      avgStrokeRate: json['avg_stroke_rate'] as int,
      avgHeartRate: json['avg_heart_rate'] as int?,
      minHeartRate: json['min_heart_rate'] as int?,
      maxHeartRate: json['max_heart_rate'] as int?,
      endingHeartRate: json['ending_heart_rate'] as int?,
      avgWatts: json['avg_watts'] as int,
      calories: json['calories'] as int,
      strokeCount: (json['stroke_count'] as int?) ?? 0,
      dragFactor: json['drag_factor'] as int?,
      timezone: (json['timezone'] as String?) ?? 'UTC',
      splits: (json['splits'] as List<dynamic>?)
              ?.map((e) => SplitData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      timeSamples: (json['time_samples'] as List<dynamic>?)
              ?.map((e) => WorkoutTimeSample.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      syncedToC2: (json['synced_to_c2'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Omit 'id' when empty — let Supabase generate the UUID
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      if (workoutId != null) 'workout_id': workoutId,
      if (workoutName != null) 'workout_name': workoutName,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt.toIso8601String(),
      'total_distance': totalDistance.toInt(),
      // DB column is 'total_time' in tenths of seconds (C2 convention)
      'total_time': totalTime.inMilliseconds ~/ 100,
      'avg_split': avgSplit,
      'avg_stroke_rate': avgStrokeRate,
      if (avgHeartRate != null) 'avg_heart_rate': avgHeartRate,
      if (minHeartRate != null) 'min_heart_rate': minHeartRate,
      if (maxHeartRate != null) 'max_heart_rate': maxHeartRate,
      if (endingHeartRate != null) 'ending_heart_rate': endingHeartRate,
      'avg_watts': avgWatts,
      'calories': calories,
      'stroke_count': strokeCount,
      if (dragFactor != null) 'drag_factor': dragFactor,
      'timezone': timezone,
      'splits': splits.map((e) => e.toJson()).toList(),
      if (timeSamples.isNotEmpty)
        'time_samples': timeSamples.map((e) => e.toJson()).toList(),
      'synced_to_c2': syncedToC2,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutResult &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
