class PlanProgress {
  final String id;
  final String userId;
  final String planId;
  final List<CompletedSession> completedSessions;
  final DateTime lastViewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlanProgress({
    required this.id,
    required this.userId,
    required this.planId,
    this.completedSessions = const [],
    required this.lastViewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isCompleted(int week, int session) {
    return completedSessions.any(
      (cs) => cs.week == week && cs.session == session,
    );
  }

  int get totalCompleted => completedSessions.length;

  factory PlanProgress.fromJson(Map<String, dynamic> json) {
    return PlanProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planId: json['plan_id'] as String,
      completedSessions: (json['completed_sessions'] as List<dynamic>?)
              ?.map((e) => CompletedSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastViewedAt: DateTime.parse(json['last_viewed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan_id': planId,
      'completed_sessions':
          completedSessions.map((cs) => cs.toJson()).toList(),
      'last_viewed_at': lastViewedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class CompletedSession {
  final int week;
  final int session;
  final String? resultId;
  final DateTime completedAt;

  const CompletedSession({
    required this.week,
    required this.session,
    this.resultId,
    required this.completedAt,
  });

  factory CompletedSession.fromJson(Map<String, dynamic> json) {
    return CompletedSession(
      week: json['week'] as int,
      session: json['session'] as int,
      resultId: json['result_id'] as String?,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'week': week,
      'session': session,
      if (resultId != null) 'result_id': resultId,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}
