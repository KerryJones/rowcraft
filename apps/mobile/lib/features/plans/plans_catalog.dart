import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/plan_progress.dart';
import '../../models/training_plan.dart';
import '../../widgets/ble_status_button.dart';
import '../../widgets/difficulty_indicator.dart';
import 'plans_provider.dart';

class PlansCatalog extends ConsumerStatefulWidget {
  const PlansCatalog({super.key});

  @override
  ConsumerState<PlansCatalog> createState() => _PlansCatalogState();
}

class _PlansCatalogState extends ConsumerState<PlansCatalog> {
  String? _selectedDifficulty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plansAsync = ref.watch(filteredPlansProvider(_selectedDifficulty));
    final continueAsync = ref.watch(lastViewedPlanProvider);
    final progressAsync = ref.watch(userPlanProgressProvider);

    // Build progress map for plan cards
    final progressMap = <String, PlanProgress>{};
    if (progressAsync.hasValue) {
      for (final p in progressAsync.value!) {
        progressMap[p.planId] = p;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans'),
        actions: const [BleStatusButton()],
      ),
      body: Column(
        children: [
          // Difficulty filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(null, 'All'),
                _buildFilterChip('beginner', 'Beginner'),
                _buildFilterChip('intermediate', 'Intermediate'),
                _buildFilterChip('advanced', 'Advanced'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Expanded(
            child: plansAsync.when(
              data: (plans) {
                if (plans.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month,
                            size: 64, color: RowCraftTheme.subtleGrey),
                        const SizedBox(height: 16),
                        Text('No plans found',
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: RowCraftTheme.subtleGrey)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(trainingPlansProvider);
                    ref.invalidate(userPlanProgressProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: plans.length +
                        (continueAsync.value != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Continue banner at top
                      if (continueAsync.value != null && index == 0) {
                        final data = continueAsync.value!;
                        return _ContinueBanner(
                          plan: data.plan,
                          progress: data.progress,
                        );
                      }

                      final planIndex =
                          continueAsync.value != null ? index - 1 : index;
                      final plan = plans[planIndex];
                      return _PlanCard(
                        plan: plan,
                        progress: progressMap[plan.id],
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: RowCraftTheme.errorRose),
                    const SizedBox(height: 16),
                    Text('Failed to load plans',
                        style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(trainingPlansProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? difficulty, String label) {
    final isSelected = _selectedDifficulty == difficulty;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedDifficulty = isSelected ? null : difficulty;
          });
        },
      ),
    );
  }
}

class _ContinueBanner extends StatelessWidget {
  final TrainingPlan plan;
  final PlanProgress progress;

  const _ContinueBanner({required this.plan, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = plan.totalSessions;
    final completedCount = progress.totalCompleted;
    final progressFraction = total > 0 ? completedCount / total : 0.0;

    // Find current week: first week with an incomplete session
    int currentWeek = plan.weeks.lastOrNull?.weekNumber ?? 1;
    for (final week in plan.weeks) {
      bool weekComplete = true;
      for (int i = 0; i < week.sessions.length; i++) {
        if (!progress.isCompleted(week.weekNumber, i)) {
          weekComplete = false;
          break;
        }
      }
      if (!weekComplete) {
        currentWeek = week.weekNumber;
        break;
      }
    }

    // Count completed sessions in current week
    final currentWeekData =
        plan.weeks.where((w) => w.weekNumber == currentWeek).firstOrNull;
    final weekSessions = currentWeekData?.sessions.length ?? 0;
    int doneInWeek = 0;
    if (currentWeekData != null) {
      for (int i = 0; i < currentWeekData.sessions.length; i++) {
        if (progress.isCompleted(currentWeek, i)) doneInWeek++;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: RowCraftTheme.primaryBlue.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: RowCraftTheme.primaryBlue.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/plans/${plan.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Continue: ${plan.title}',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: RowCraftTheme.metricWhite,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 16, color: RowCraftTheme.primaryBlue),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Week $currentWeek · $doneInWeek of $weekSessions done · $completedCount/$total total',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 6,
                  backgroundColor: RowCraftTheme.surfaceContainerHigh,
                  valueColor:
                      const AlwaysStoppedAnimation(RowCraftTheme.primaryBlue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final TrainingPlan plan;
  final PlanProgress? progress;

  const _PlanCard({required this.plan, this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasProgress =
        progress != null && progress!.totalCompleted > 0;
    final total = plan.totalSessions;
    final completed = progress?.totalCompleted ?? 0;
    final progressFraction =
        hasProgress && total > 0 ? completed / total : 0.0;

    return Card(
      child: InkWell(
        onTap: () => context.push('/plans/${plan.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(plan.title,
                        style: theme.textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  DifficultyIndicator(
                    level: DifficultyIndicator.levelFromDifficulty(
                        plan.difficulty),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${plan.durationWeeks} weeks · ${plan.sessionsPerWeek}x/week',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: RowCraftTheme.primaryBlue,
                    fontWeight: FontWeight.w500),
              ),
              if (plan.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(plan.description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              // Progress bar
              if (hasProgress) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progressFraction,
                          minHeight: 4,
                          backgroundColor: RowCraftTheme.surfaceContainerHigh,
                          valueColor: const AlwaysStoppedAnimation(
                              RowCraftTheme.primaryBlue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$completed/$total',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: RowCraftTheme.subtleGrey),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
