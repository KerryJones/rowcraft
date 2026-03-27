class TrainingPlan {
  final String id;
  final String slug;
  final String title;
  final String description;
  final String difficulty;
  final int durationWeeks;
  final int sessionsPerWeek;
  final List<String> tags;
  final List<PlanWeek> weeks;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingPlan({
    required this.id,
    required this.slug,
    required this.title,
    this.description = '',
    required this.difficulty,
    required this.durationWeeks,
    required this.sessionsPerWeek,
    this.tags = const [],
    this.weeks = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalSessions =>
      weeks.fold(0, (sum, w) => sum + w.sessions.length);

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    return TrainingPlan(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      difficulty: json['difficulty'] as String,
      durationWeeks: json['duration_weeks'] as int,
      sessionsPerWeek: json['sessions_per_week'] as int,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      weeks: (json['weeks'] as List<dynamic>?)
              ?.map((e) => PlanWeek.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'description': description,
      'difficulty': difficulty,
      'duration_weeks': durationWeeks,
      'sessions_per_week': sessionsPerWeek,
      'tags': tags,
      'weeks': weeks.map((w) => w.toJson()).toList(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PlanWeek {
  final int weekNumber;
  final String title;
  final List<PlanSession> sessions;

  const PlanWeek({
    required this.weekNumber,
    this.title = '',
    this.sessions = const [],
  });

  factory PlanWeek.fromJson(Map<String, dynamic> json) {
    return PlanWeek(
      weekNumber: json['week_number'] as int,
      title: (json['title'] as String?) ?? '',
      sessions: (json['sessions'] as List<dynamic>?)
              ?.map((e) => PlanSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'week_number': weekNumber,
      'title': title,
      'sessions': sessions.map((s) => s.toJson()).toList(),
    };
  }
}

class PlanSession {
  final String dayLabel;
  final String workoutId;
  final String? notes;

  const PlanSession({
    required this.dayLabel,
    required this.workoutId,
    this.notes,
  });

  factory PlanSession.fromJson(Map<String, dynamic> json) {
    return PlanSession(
      dayLabel: json['day_label'] as String,
      workoutId: json['workout_id'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_label': dayLabel,
      'workout_id': workoutId,
      if (notes != null) 'notes': notes,
    };
  }
}
