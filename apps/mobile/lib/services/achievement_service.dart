import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/achievement.dart';
import '../models/workout_result.dart';
import 'supabase_service.dart';

final achievementServiceProvider = Provider<AchievementService>((ref) {
  return AchievementService(ref.watch(supabaseServiceProvider));
});

class AchievementService {
  final SupabaseService _supabaseService;

  final List<Achievement> _all = [];
  bool _loaded = false;

  AchievementService(this._supabaseService);

  bool get isLoaded => _loaded;
  List<Achievement> get cachedAchievements => List.unmodifiable(_all);

  bool isEarned(AchievementType type, int threshold) =>
      _all.any((a) => a.achievementType == type && a.threshold == threshold);

  /// Load achievements from Supabase into cache.
  Future<void> load() async {
    try {
      final achievements = await _supabaseService.getAchievements();
      _all
        ..clear()
        ..addAll(achievements);
      _loaded = true;
    } catch (e) {
      dev.log('AchievementService.load failed: $e', name: 'rowcraft');
    }
  }

  /// Check all achievement types after a workout save.
  /// [totalDistance] and [totalWorkouts] are cumulative values.
  /// [results] is the full list of workout results (for streak calculation).
  /// [completedPlanCount] is the number of fully completed training plans.
  /// Returns list of newly earned achievements.
  Future<List<Achievement>> checkAchievements({
    required String userId,
    required double totalDistance,
    required int totalWorkouts,
    required int completedPlanCount,
    required List<WorkoutResult> results,
    String? resultId,
  }) async {
    final now = DateTime.now();
    final streak = _computeCurrentStreak(results);

    // Map current values to achievement types
    final currentValues = <AchievementType, num>{
      AchievementType.totalDistance: totalDistance,
      AchievementType.workoutCount: totalWorkouts,
      AchievementType.planCompleted: completedPlanCount,
      AchievementType.streakDays: streak,
    };

    // Collect all newly crossed thresholds
    final pending = <(AchievementType, int)>[];
    for (final type in AchievementType.values) {
      final value = currentValues[type]!;
      for (final threshold in type.thresholds) {
        if (value >= threshold && !isEarned(type, threshold)) {
          pending.add((type, threshold));
        }
      }
    }

    if (pending.isEmpty) return [];

    // Insert all in parallel
    final results2 = await Future.wait(
      pending.map((entry) => _insert(
            userId: userId,
            type: entry.$1,
            threshold: entry.$2,
            achievedAt: now,
            resultId: resultId,
          )),
    );

    return results2.whereType<Achievement>().toList();
  }

  /// Compute the current consecutive-day streak ending today or yesterday.
  int _computeCurrentStreak(List<WorkoutResult> results) {
    if (results.isEmpty) return 0;

    // Get distinct local dates from started_at
    final dates = <DateTime>{};
    for (final r in results) {
      final local = r.startedAt.toLocal();
      dates.add(DateTime(local.year, local.month, local.day));
    }

    final sorted = dates.toList()..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterday = todayDate.subtract(const Duration(days: 1));

    // Start from today or yesterday
    if (sorted.first != todayDate && sorted.first != yesterday) {
      return 0;
    }

    var streak = 1;
    var current = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final prev = current.subtract(const Duration(days: 1));
      if (sorted[i] == prev) {
        streak++;
        current = sorted[i];
      } else {
        break;
      }
    }

    return streak;
  }

  Future<Achievement?> _insert({
    required String userId,
    required AchievementType type,
    required int threshold,
    required DateTime achievedAt,
    String? resultId,
  }) async {
    final achievement = Achievement(
      id: '',
      userId: userId,
      achievementType: type,
      threshold: threshold,
      achievedAt: achievedAt,
      resultId: resultId,
      createdAt: achievedAt,
    );

    try {
      final saved = await _supabaseService.insertAchievement(achievement);
      _all.add(saved);
      return saved;
    } catch (e) {
      dev.log('AchievementService._insert(${type.key}/$threshold) failed: $e',
          name: 'rowcraft');
      return null;
    }
  }

  /// Backfill achievements from existing data.
  Future<void> backfill({
    required String userId,
    required double totalDistance,
    required int totalWorkouts,
    required int completedPlanCount,
    required List<WorkoutResult> results,
  }) async {
    if (_all.isNotEmpty) return;

    await checkAchievements(
      userId: userId,
      totalDistance: totalDistance,
      totalWorkouts: totalWorkouts,
      completedPlanCount: completedPlanCount,
      results: results,
    );
  }
}
