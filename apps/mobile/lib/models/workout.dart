import 'workout_segment.dart';

enum WorkoutType {
  singleDistance,
  singleTime,
  intervals,
  variableIntervals;

  /// Serialize to snake_case to match DB check constraint and web types.
  String toJson() => switch (this) {
        WorkoutType.singleDistance => 'single_distance',
        WorkoutType.singleTime => 'single_time',
        WorkoutType.intervals => 'intervals',
        WorkoutType.variableIntervals => 'variable_intervals',
      };

  static WorkoutType fromJson(String json) => switch (json) {
        'single_distance' => WorkoutType.singleDistance,
        'single_time' => WorkoutType.singleTime,
        'intervals' => WorkoutType.intervals,
        'variable_intervals' => WorkoutType.variableIntervals,
        // Fallback for camelCase (legacy)
        _ => WorkoutType.values.firstWhere(
            (e) => e.name == json,
            orElse: () => WorkoutType.intervals,
          ),
      };
}

class Workout {
  final String id;
  final String authorId;
  final String title;
  final String description;
  final WorkoutType workoutType;
  final List<WorkoutSegment> segments;
  final List<String> tags;
  final bool isPublic;
  final int forkCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Workout({
    required this.id,
    required this.authorId,
    required this.title,
    this.description = '',
    required this.workoutType,
    this.segments = const [],
    this.tags = const [],
    this.isPublic = false,
    this.forkCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Workout copyWith({
    String? id,
    String? authorId,
    String? title,
    String? description,
    WorkoutType? workoutType,
    List<WorkoutSegment>? segments,
    List<String>? tags,
    bool? isPublic,
    int? forkCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workout(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      description: description ?? this.description,
      workoutType: workoutType ?? this.workoutType,
      segments: segments ?? this.segments,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      forkCount: forkCount ?? this.forkCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      authorId: (json['author_id'] as String?) ?? '',
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      workoutType: WorkoutType.fromJson(json['workout_type'] as String),
      segments: (json['segments'] as List<dynamic>?)
              ?.map((e) => WorkoutSegment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isPublic: (json['is_public'] as bool?) ?? false,
      forkCount: (json['fork_count'] as int?) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'title': title,
      'description': description,
      'workout_type': workoutType.toJson(),
      'segments': segments.map((e) => e.toJson()).toList(),
      'tags': tags,
      'is_public': isPublic,
      'fork_count': forkCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workout && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Workout(id: $id, title: $title, type: $workoutType)';
}
