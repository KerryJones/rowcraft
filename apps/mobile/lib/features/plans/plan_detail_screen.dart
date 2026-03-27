import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/plan_progress.dart';
import '../../models/training_plan.dart';
import '../../services/supabase_service.dart';
import 'difficulty_badge.dart';
import 'plans_provider.dart';

class PlanDetailScreen extends ConsumerStatefulWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  ConsumerState<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends ConsumerState<PlanDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Touch last_viewed_at on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(supabaseServiceProvider)
          .touchPlanLastViewed(widget.planId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(
      trainingPlansProvider.select((value) => value.whenData(
        (plans) => plans.where((p) => p.id == widget.planId).firstOrNull,
      )),
    );
    final progressAsync = ref.watch(planProgressProvider(widget.planId));

    return Scaffold(
      appBar: AppBar(title: const Text('Training Plan')),
      body: planAsync.when(
        data: (plan) {
          if (plan == null) {
            return const Center(child: Text('Plan not found'));
          }
          final progress = progressAsync.valueOrNull;
          return _PlanDetailContent(plan: plan, progress: progress);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: RowCraftTheme.errorRose)),
        ),
      ),
    );
  }
}

class _PlanDetailContent extends StatefulWidget {
  final TrainingPlan plan;
  final PlanProgress? progress;

  const _PlanDetailContent({required this.plan, this.progress});

  @override
  State<_PlanDetailContent> createState() => _PlanDetailContentState();
}

class _PlanDetailContentState extends State<_PlanDetailContent> {
  late int _expandedWeek;

  @override
  void initState() {
    super.initState();
    _expandedWeek = _findCurrentWeek();
  }

  @override
  void didUpdateWidget(covariant _PlanDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      setState(() => _expandedWeek = _findCurrentWeek());
    }
  }

  int _findCurrentWeek() {
    if (widget.progress == null) return 1;
    // Find first week with incomplete sessions
    for (final week in widget.plan.weeks) {
      for (int i = 0; i < week.sessions.length; i++) {
        if (!widget.progress!.isCompleted(week.weekNumber, i)) {
          return week.weekNumber;
        }
      }
    }
    return widget.plan.weeks.lastOrNull?.weekNumber ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = widget.progress?.totalCompleted ?? 0;
    final total = widget.plan.totalSessions;
    final progressFraction = total > 0 ? completed / total : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero section
        Text(widget.plan.title, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            DifficultyBadge(difficulty: widget.plan.difficulty),
            const SizedBox(width: 12),
            Text(
              '${widget.plan.durationWeeks} weeks · ${widget.plan.sessionsPerWeek}x/week',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: RowCraftTheme.subtleGrey),
            ),
          ],
        ),
        if (widget.plan.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(widget.plan.description, style: theme.textTheme.bodyMedium),
        ],

        // Progress bar
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$completed of $total sessions',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: RowCraftTheme.metricWhite)),
            Text('${(progressFraction * 100).toInt()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: RowCraftTheme.primaryBlue)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressFraction,
            minHeight: 8,
            backgroundColor: RowCraftTheme.surfaceContainerHigh,
            valueColor:
                const AlwaysStoppedAnimation(RowCraftTheme.primaryBlue),
          ),
        ),

        // Week accordion
        const SizedBox(height: 24),
        for (final week in widget.plan.weeks)
          _WeekSection(
            week: week,
            planId: widget.plan.id,
            progress: widget.progress,
            isExpanded: week.weekNumber == _expandedWeek,
            onToggle: () {
              setState(() {
                _expandedWeek = _expandedWeek == week.weekNumber
                    ? -1
                    : week.weekNumber;
              });
            },
          ),
      ],
    );
  }
}

class _WeekSection extends ConsumerWidget {
  final PlanWeek week;
  final String planId;
  final PlanProgress? progress;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _WeekSection({
    required this.week,
    required this.planId,
    this.progress,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final titlesAsync = ref.watch(_planWorkoutTitlesProvider(planId));
    final titles = titlesAsync.valueOrNull ?? {};

    // Count completed sessions in this week
    int completedInWeek = 0;
    for (int i = 0; i < week.sessions.length; i++) {
      if (progress?.isCompleted(week.weekNumber, i) == true) {
        completedInWeek++;
      }
    }
    final allDone = completedInWeek == week.sessions.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Week header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: isExpanded
                  ? Radius.zero
                  : const Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (allDone)
                    const Icon(Icons.check_circle,
                        size: 20, color: RowCraftTheme.successGreen)
                  else
                    Icon(Icons.circle_outlined,
                        size: 20, color: RowCraftTheme.subtleGrey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Week ${week.weekNumber}',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600),
                        ),
                        if (week.title.isNotEmpty)
                          Text(week.title, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(
                    '$completedInWeek/${week.sessions.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: RowCraftTheme.subtleGrey),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: RowCraftTheme.subtleGrey,
                  ),
                ],
              ),
            ),
          ),

          // Sessions (expanded)
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  for (int i = 0; i < week.sessions.length; i++)
                    _SessionRow(
                      session: week.sessions[i],
                      weekNumber: week.weekNumber,
                      sessionIndex: i,
                      planId: planId,
                      isCompleted:
                          progress?.isCompleted(week.weekNumber, i) == true,
                      isNextUp: _isNextUp(i),
                      workoutTitle: titles[week.sessions[i].workoutId] ??
                          week.sessions[i].dayLabel,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _isNextUp(int sessionIndex) {
    if (progress == null) return sessionIndex == 0;
    // First incomplete session in this week
    for (int i = 0; i < week.sessions.length; i++) {
      if (progress?.isCompleted(week.weekNumber, i) != true) {
        return i == sessionIndex;
      }
    }
    return false;
  }
}

class _SessionRow extends StatelessWidget {
  final PlanSession session;
  final int weekNumber;
  final int sessionIndex;
  final String planId;
  final bool isCompleted;
  final bool isNextUp;
  final String workoutTitle;

  const _SessionRow({
    required this.session,
    required this.weekNumber,
    required this.sessionIndex,
    required this.planId,
    required this.isCompleted,
    required this.isNextUp,
    required this.workoutTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        context.push(
          '/workout/${session.workoutId}'
          '?plan=$planId&week=$weekNumber&session=$sessionIndex',
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: isNextUp
            ? BoxDecoration(
                color: RowCraftTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        RowCraftTheme.primaryBlue.withValues(alpha: 0.3)),
              )
            : null,
        child: Row(
          children: [
            // Status icon
            if (isCompleted)
              const Icon(Icons.check_circle,
                  size: 20, color: RowCraftTheme.successGreen)
            else if (isNextUp)
              const Icon(Icons.play_circle_filled,
                  size: 20, color: RowCraftTheme.primaryBlue)
            else
              Icon(Icons.circle_outlined,
                  size: 20, color: RowCraftTheme.subtleGrey),
            const SizedBox(width: 12),
            // Session info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${session.dayLabel}: $workoutTitle',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isNextUp ? FontWeight.w600 : FontWeight.w400,
                      color: isCompleted
                          ? RowCraftTheme.subtleGrey
                          : RowCraftTheme.metricWhite,
                    ),
                  ),
                  if (session.notes != null)
                    Text(session.notes!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20,
                color: RowCraftTheme.subtleGrey),
          ],
        ),
      ),
    );
  }
}

/// Batch-fetch all workout titles for a plan's sessions (avoids N+1 queries).
/// Uses the already-cached plan from trainingPlansProvider to collect IDs,
/// then fetches only those workouts via an `in_` filter.
final _planWorkoutTitlesProvider =
    FutureProvider.family<Map<String, String>, String>(
        (ref, planId) async {
  // Capture refs before any await to avoid post-dispose StateError.
  final plansFuture = ref.watch(trainingPlansProvider.future);
  final service = ref.watch(supabaseServiceProvider);

  final plans = await plansFuture;
  final plan = plans.where((p) => p.id == planId).firstOrNull;
  if (plan == null) return {};

  final workoutIds = <String>{};
  for (final week in plan.weeks) {
    for (final session in week.sessions) {
      workoutIds.add(session.workoutId);
    }
  }
  if (workoutIds.isEmpty) return {};

  final workouts = await service.getWorkoutsByIds(workoutIds.toList());
  return {for (final w in workouts) w.id: w.title};
});

