enum SegmentType {
  work,
  rest,
  warmup,
  cooldown;

  String toJson() => name;

  static SegmentType fromJson(String json) =>
      SegmentType.values.firstWhere((e) => e.name == json);
}

enum DurationType {
  time,
  distance,
  calories;

  String toJson() => name;

  static DurationType fromJson(String json) =>
      DurationType.values.firstWhere((e) => e.name == json);
}

class SplitTarget {
  final double min;
  final double max;

  const SplitTarget({required this.min, required this.max});

  factory SplitTarget.fromJson(Map<String, dynamic> json) {
    return SplitTarget(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};

  SplitTarget copyWith({double? min, double? max}) {
    return SplitTarget(min: min ?? this.min, max: max ?? this.max);
  }
}

class StrokeRateTarget {
  final int min;
  final int max;

  const StrokeRateTarget({required this.min, required this.max});

  factory StrokeRateTarget.fromJson(Map<String, dynamic> json) {
    return StrokeRateTarget(
      min: (json['min'] as num).toInt(),
      max: (json['max'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};

  StrokeRateTarget copyWith({int? min, int? max}) {
    return StrokeRateTarget(min: min ?? this.min, max: max ?? this.max);
  }
}

class WorkoutSegment {
  final SegmentType type;
  final DurationType durationType;
  final double durationValue;
  final SplitTarget? targetSplit;
  final StrokeRateTarget? targetStrokeRate;
  final int? targetHrZone;

  const WorkoutSegment({
    required this.type,
    required this.durationType,
    required this.durationValue,
    this.targetSplit,
    this.targetStrokeRate,
    this.targetHrZone,
  });

  WorkoutSegment copyWith({
    SegmentType? type,
    DurationType? durationType,
    double? durationValue,
    SplitTarget? targetSplit,
    StrokeRateTarget? targetStrokeRate,
    int? targetHrZone,
  }) {
    return WorkoutSegment(
      type: type ?? this.type,
      durationType: durationType ?? this.durationType,
      durationValue: durationValue ?? this.durationValue,
      targetSplit: targetSplit ?? this.targetSplit,
      targetStrokeRate: targetStrokeRate ?? this.targetStrokeRate,
      targetHrZone: targetHrZone ?? this.targetHrZone,
    );
  }

  factory WorkoutSegment.fromJson(Map<String, dynamic> json) {
    return WorkoutSegment(
      type: SegmentType.fromJson(json['type'] as String),
      durationType: DurationType.fromJson(json['duration_type'] as String),
      durationValue: (json['duration_value'] as num).toDouble(),
      targetSplit: json['target_split'] != null
          ? SplitTarget.fromJson(json['target_split'] as Map<String, dynamic>)
          : null,
      targetStrokeRate: json['target_stroke_rate'] != null
          ? StrokeRateTarget.fromJson(
              json['target_stroke_rate'] as Map<String, dynamic>)
          : null,
      targetHrZone: json['target_hr_zone'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toJson(),
      'duration_type': durationType.toJson(),
      'duration_value': durationValue,
      if (targetSplit != null) 'target_split': targetSplit!.toJson(),
      if (targetStrokeRate != null)
        'target_stroke_rate': targetStrokeRate!.toJson(),
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
      'WorkoutSegment(${type.name}, $durationLabel)';
}
