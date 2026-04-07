enum DurationType {
  time,
  distance,
  calories;

  String toJson() => name;

  static DurationType fromJson(String json) =>
      DurationType.values.firstWhere((e) => e.name == json);
}

class WorkoutSegment {
  final DurationType durationType;
  final double durationValue;

  /// FTP percentage target (0–200). Higher % = more watts = faster pace.
  final int? targetIntensity;

  /// Strokes per minute target (10–50).
  final int? targetStrokeRate;

  /// HR zone (1–5) derived from targetIntensity at build/save time. Read-only.
  final int? targetHrZone;

  const WorkoutSegment({
    required this.durationType,
    required this.durationValue,
    this.targetIntensity,
    this.targetStrokeRate,
    this.targetHrZone,
  });

  /// True when this segment has no targets — pure rest/recovery time.
  bool get isRest => targetIntensity == null && targetStrokeRate == null;

  WorkoutSegment copyWith({
    DurationType? durationType,
    double? durationValue,
    int? targetIntensity,
    int? targetStrokeRate,
    int? targetHrZone,
  }) {
    return WorkoutSegment(
      durationType: durationType ?? this.durationType,
      durationValue: durationValue ?? this.durationValue,
      targetIntensity: targetIntensity ?? this.targetIntensity,
      targetStrokeRate: targetStrokeRate ?? this.targetStrokeRate,
      targetHrZone: targetHrZone ?? this.targetHrZone,
    );
  }

  factory WorkoutSegment.fromJson(Map<String, dynamic> json) {
    return WorkoutSegment(
      durationType: DurationType.fromJson(json['duration_type'] as String),
      durationValue: (json['duration_value'] as num).toDouble(),
      targetIntensity: (json['target_intensity'] as num?)?.toInt(),
      targetStrokeRate: (json['target_stroke_rate'] as num?)?.toInt(),
      targetHrZone: (json['target_hr_zone'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'duration_type': durationType.toJson(),
      'duration_value': durationValue,
      if (targetIntensity != null) 'target_intensity': targetIntensity,
      if (targetStrokeRate != null) 'target_stroke_rate': targetStrokeRate,
      if (targetHrZone != null) 'target_hr_zone': targetHrZone,
    };
  }

  /// Human-readable duration label, e.g. "2000m", "5:00", "100cal"
  String get durationLabel {
    switch (durationType) {
      case DurationType.distance:
        return '${durationValue.toInt()}m';
      case DurationType.time:
        final totalSeconds = durationValue.toInt();
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      case DurationType.calories:
        return '${durationValue.toInt()}cal';
    }
  }

  @override
  String toString() =>
      'WorkoutSegment(${isRest ? 'rest' : 'active'}, $durationLabel)';
}
