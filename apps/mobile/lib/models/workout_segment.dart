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

/// FTP-relative intensity target as percentage of FTP watts (0–200).
///
/// Higher % = more watts = faster pace. The app resolves these to
/// absolute pace using the user's FTP: watts = ftpWatts × pct / 100,
/// then converts watts → pace via the C2 formula.
class IntensityTarget {
  final int min; // lower bound FTP % (less intense / slower)
  final int max; // upper bound FTP % (more intense / faster)

  const IntensityTarget({required this.min, required this.max});

  factory IntensityTarget.fromJson(Map<String, dynamic> json) {
    return IntensityTarget(
      min: (json['min'] as num).toInt(),
      max: (json['max'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};

  /// The exact target intensity (midpoint of the range).
  int get midpoint => ((min + max) / 2).round();

  IntensityTarget copyWith({int? min, int? max}) {
    return IntensityTarget(min: min ?? this.min, max: max ?? this.max);
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

  /// The exact target stroke rate (midpoint of the tolerance range).
  int get midpoint => ((min + max) / 2).round();

  StrokeRateTarget copyWith({int? min, int? max}) {
    return StrokeRateTarget(min: min ?? this.min, max: max ?? this.max);
  }
}

class WorkoutSegment {
  final SegmentType type;
  final DurationType durationType;
  final double durationValue;
  final IntensityTarget? targetIntensity;
  final StrokeRateTarget? targetStrokeRate;
  final int? targetHrZone;

  const WorkoutSegment({
    required this.type,
    required this.durationType,
    required this.durationValue,
    this.targetIntensity,
    this.targetStrokeRate,
    this.targetHrZone,
  });

  WorkoutSegment copyWith({
    SegmentType? type,
    DurationType? durationType,
    double? durationValue,
    IntensityTarget? targetIntensity,
    StrokeRateTarget? targetStrokeRate,
    int? targetHrZone,
  }) {
    return WorkoutSegment(
      type: type ?? this.type,
      durationType: durationType ?? this.durationType,
      durationValue: durationValue ?? this.durationValue,
      targetIntensity: targetIntensity ?? this.targetIntensity,
      targetStrokeRate: targetStrokeRate ?? this.targetStrokeRate,
      targetHrZone: targetHrZone ?? this.targetHrZone,
    );
  }

  factory WorkoutSegment.fromJson(Map<String, dynamic> json) {
    return WorkoutSegment(
      type: SegmentType.fromJson(json['type'] as String),
      durationType: DurationType.fromJson(json['duration_type'] as String),
      durationValue: (json['duration_value'] as num).toDouble(),
      targetIntensity: json['target_intensity'] != null
          ? IntensityTarget.fromJson(json['target_intensity'] as Map<String, dynamic>)
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
      if (targetIntensity != null) 'target_intensity': targetIntensity!.toJson(),
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
