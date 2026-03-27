import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/plan_progress.dart';
import '../../models/training_plan.dart';
import '../../services/supabase_service.dart';

/// All active training plans.
final trainingPlansProvider = FutureProvider<List<TrainingPlan>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getTrainingPlans();
});

/// All plan progress for the current user.
final userPlanProgressProvider =
    FutureProvider<List<PlanProgress>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getUserPlanProgress();
});

/// Progress for a specific plan.
final planProgressProvider =
    FutureProvider.family<PlanProgress?, String>((ref, planId) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getPlanProgress(planId);
});

/// The most recently viewed plan with incomplete sessions (for continue banner).
final lastViewedPlanProvider =
    FutureProvider<({TrainingPlan plan, PlanProgress progress})?>(
        (ref) async {
  final progressList = await ref.watch(userPlanProgressProvider.future);
  if (progressList.isEmpty) return null;

  final plans = await ref.watch(trainingPlansProvider.future);
  if (plans.isEmpty) return null;

  // progressList is already sorted by last_viewed_at desc
  for (final progress in progressList) {
    final plan = plans.where((p) => p.id == progress.planId).firstOrNull;
    if (plan == null) continue;

    // Check if there are incomplete sessions
    if (progress.totalCompleted < plan.totalSessions) {
      return (plan: plan, progress: progress);
    }
  }

  return null;
});

/// Plans filtered by difficulty.
final filteredPlansProvider = FutureProvider.family<List<TrainingPlan>, String?>(
    (ref, difficulty) async {
  final plans = await ref.watch(trainingPlansProvider.future);
  if (difficulty == null) return plans;
  return plans.where((p) => p.difficulty == difficulty).toList();
});
