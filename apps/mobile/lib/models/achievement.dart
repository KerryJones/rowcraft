/// Achievement category with thresholds.
enum AchievementType {
  totalDistance(
    'total_distance',
    'Total Distance',
    [100000, 250000, 500000, 1000000, 2000000, 5000000, 10000000],
  ),
  workoutCount(
    'workout_count',
    'Workouts Completed',
    [1, 10, 25, 50, 100, 250, 500],
  ),
  planCompleted(
    'plan_completed',
    'Plans Completed',
    [1, 3, 5, 10],
  ),
  streakDays(
    'streak_days',
    'Streak',
    [3, 7, 14, 30, 60, 90],
  );

  final String key;
  final String label;
  final List<int> thresholds;

  const AchievementType(this.key, this.label, this.thresholds);

  static AchievementType? fromKey(String key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

class Achievement {
  final String id;
  final String userId;
  final AchievementType achievementType;
  final int threshold;
  final DateTime achievedAt;
  final String? resultId;
  final DateTime createdAt;

  const Achievement({
    required this.id,
    required this.userId,
    required this.achievementType,
    required this.threshold,
    required this.achievedAt,
    this.resultId,
    required this.createdAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      achievementType: AchievementType.fromKey(
            json['achievement_type'] as String,
          ) ??
          AchievementType.totalDistance,
      threshold: json['threshold'] as int,
      achievedAt: DateTime.parse(json['achieved_at'] as String),
      resultId: json['result_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'achievement_type': achievementType.key,
      'threshold': threshold,
      'achieved_at': achievedAt.toIso8601String(),
      if (resultId != null) 'result_id': resultId,
    };
  }
}
