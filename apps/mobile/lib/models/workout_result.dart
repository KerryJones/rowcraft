class SplitData {
  final int intervalIndex;
  final double distance;
  final Duration time;
  final int avgPace;
  final int avgStrokeRate;
  final int avgWatts;
  final int? avgHeartRate;
  final int calories;

  const SplitData({
    required this.intervalIndex,
    required this.distance,
    required this.time,
    required this.avgPace,
    required this.avgStrokeRate,
    required this.avgWatts,
    this.avgHeartRate,
    required this.calories,
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
      calories: json['calories'] as int,
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
      'calories': calories,
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
  final DateTime startedAt;
  final DateTime finishedAt;
  final double totalDistance;
  final Duration totalTime;
  final int avgSplit;
  final int avgStrokeRate;
  final int? avgHeartRate;
  final int avgWatts;
  final int calories;
  final List<SplitData> splits;
  final bool syncedToC2;

  const WorkoutResult({
    required this.id,
    required this.userId,
    this.workoutId,
    required this.startedAt,
    required this.finishedAt,
    required this.totalDistance,
    required this.totalTime,
    required this.avgSplit,
    required this.avgStrokeRate,
    this.avgHeartRate,
    required this.avgWatts,
    required this.calories,
    this.splits = const [],
    this.syncedToC2 = false,
  });

  WorkoutResult copyWith({
    String? id,
    String? userId,
    String? workoutId,
    DateTime? startedAt,
    DateTime? finishedAt,
    double? totalDistance,
    Duration? totalTime,
    int? avgSplit,
    int? avgStrokeRate,
    int? avgHeartRate,
    int? avgWatts,
    int? calories,
    List<SplitData>? splits,
    bool? syncedToC2,
  }) {
    return WorkoutResult(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workoutId: workoutId ?? this.workoutId,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTime: totalTime ?? this.totalTime,
      avgSplit: avgSplit ?? this.avgSplit,
      avgStrokeRate: avgStrokeRate ?? this.avgStrokeRate,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      avgWatts: avgWatts ?? this.avgWatts,
      calories: calories ?? this.calories,
      splits: splits ?? this.splits,
      syncedToC2: syncedToC2 ?? this.syncedToC2,
    );
  }

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
      id: json['id'] as String,
      userId: json['user_id'] as String,
      workoutId: json['workout_id'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: DateTime.parse(json['finished_at'] as String),
      totalDistance: (json['total_distance'] as num).toDouble(),
      totalTime: totalTimeDuration,
      avgSplit: json['avg_split'] as int,
      avgStrokeRate: json['avg_stroke_rate'] as int,
      avgHeartRate: json['avg_heart_rate'] as int?,
      avgWatts: json['avg_watts'] as int,
      calories: json['calories'] as int,
      splits: (json['splits'] as List<dynamic>?)
              ?.map((e) => SplitData.fromJson(e as Map<String, dynamic>))
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
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt.toIso8601String(),
      'total_distance': totalDistance.toInt(),
      // DB column is 'total_time' in tenths of seconds (C2 convention)
      'total_time': totalTime.inMilliseconds ~/ 100,
      'avg_split': avgSplit,
      'avg_stroke_rate': avgStrokeRate,
      if (avgHeartRate != null) 'avg_heart_rate': avgHeartRate,
      'avg_watts': avgWatts,
      'calories': calories,
      'splits': splits.map((e) => e.toJson()).toList(),
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
