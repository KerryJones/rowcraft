/// PR type identifiers — each maps to a specific performance metric.
enum PrType {
  fastest500m('fastest_500m', 'Fastest 500m', true),
  fastest2k('fastest_2k', 'Fastest 2K', true),
  fastest5k('fastest_5k', 'Fastest 5K', true),
  fastest6k('fastest_6k', 'Fastest 6K', true),
  fastest10k('fastest_10k', 'Fastest 10K', true),
  fastestHalfMarathon('fastest_half_marathon', 'Fastest Half Marathon', true),
  fastestMarathon('fastest_marathon', 'Fastest Marathon', true),
  highestFtp('highest_ftp', 'Highest FTP', false),
  longestDistance('longest_distance', 'Longest Distance', false);

  final String key;
  final String label;

  /// When true, a lower value is better (pace PRs).
  final bool lowerIsBetter;

  const PrType(this.key, this.label, this.lowerIsBetter);

  static PrType? fromKey(String key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

class PersonalRecord {
  final String id;
  final String userId;
  final PrType prType;
  final int value;
  final String? resultId;
  final DateTime achievedAt;
  final int? previousValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalRecord({
    required this.id,
    required this.userId,
    required this.prType,
    required this.value,
    this.resultId,
    required this.achievedAt,
    this.previousValue,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) {
    return PersonalRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      prType: PrType.fromKey(json['pr_type'] as String) ?? PrType.fastest500m,
      value: json['value'] as int,
      resultId: json['result_id'] as String?,
      achievedAt: DateTime.parse(json['achieved_at'] as String),
      previousValue: json['previous_value'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'pr_type': prType.key,
      'value': value,
      if (resultId != null) 'result_id': resultId,
      'achieved_at': achievedAt.toIso8601String(),
      if (previousValue != null) 'previous_value': previousValue,
    };
  }

  PersonalRecord copyWith({
    String? id,
    String? userId,
    PrType? prType,
    int? value,
    String? resultId,
    DateTime? achievedAt,
    int? previousValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      prType: prType ?? this.prType,
      value: value ?? this.value,
      resultId: resultId ?? this.resultId,
      achievedAt: achievedAt ?? this.achievedAt,
      previousValue: previousValue ?? this.previousValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
