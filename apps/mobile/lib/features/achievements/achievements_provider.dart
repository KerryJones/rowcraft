import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/personal_record.dart';
import '../../services/achievement_service.dart';
import '../../services/pr_service.dart';
import '../../services/supabase_service.dart';
import '../history/history_provider.dart';
import '../plans/plans_provider.dart';
import '../profile/profile_screen.dart' show ftpHistoryProvider;

/// Loads PRs and achievements on first access, triggers backfill if needed.
final achievementsInitProvider = FutureProvider<void>((ref) async {
  final prService = ref.watch(prServiceProvider);
  final achievementService = ref.watch(achievementServiceProvider);

  // Load from Supabase
  await Future.wait([prService.load(), achievementService.load()]);

  // Backfill if this is a fresh install (no PRs/achievements yet)
  final supabase = ref.read(supabaseServiceProvider);
  final userId = supabase.currentUserId;
  if (userId == null) return;

  final results = await ref.read(workoutHistoryProvider.future);

  if (prService.isLoaded && prService.cachedPRs.isEmpty && results.isNotEmpty) {
    final ftpHistory = await ref.read(ftpHistoryProvider.future);
    await prService.backfill(results, userId, ftpHistory: ftpHistory);
  }

  if (achievementService.isLoaded &&
      achievementService.cachedAchievements.isEmpty &&
      results.isNotEmpty) {
    final completedPlanCount =
        await ref.read(completedPlanCountProvider.future);
    final totalDistance = results.fold(0.0, (sum, r) => sum + r.totalDistance);
    final totalWorkouts = results.length;

    await achievementService.backfill(
      userId: userId,
      totalDistance: totalDistance,
      totalWorkouts: totalWorkouts,
      completedPlanCount: completedPlanCount,
      results: results,
    );
  }
});

/// All personal records (cached).
final personalRecordsProvider =
    Provider<Map<PrType, PersonalRecord>>((ref) {
  final prService = ref.watch(prServiceProvider);
  return prService.cachedPRs;
});

/// All achievements (cached).
final achievementListProvider = Provider<List<Achievement>>((ref) {
  final achievementService = ref.watch(achievementServiceProvider);
  return achievementService.cachedAchievements;
});
