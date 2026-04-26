import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../models/achievement.dart';
import '../../models/personal_record.dart';
import '../../utils/pace_utils.dart' show formatPace, wattsToPaceStringNoTenths;
import '../../utils/workout_utils.dart' show formatDistanceKm, formatDistanceShort;
import '../../widgets/content_constraint.dart';
import '../../widgets/row_craft_app_bar.dart';
import 'achievements_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initAsync = ref.watch(achievementsInitProvider);

    return Scaffold(
      appBar: const RowCraftAppBar(title: 'Achievements'),
      body: initAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading achievements: $e',
              style: const TextStyle(color: RowCraftTheme.errorRose)),
        ),
        data: (_) => ContentConstraint(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _PersonalRecordsSection(),
              SizedBox(height: 24),
              _AchievementsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Personal Records
// ---------------------------------------------------------------------------

class _PersonalRecordsSection extends ConsumerWidget {
  const _PersonalRecordsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prs = ref.watch(personalRecordsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Personal Records', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final prType in PrType.values)
                  _PrTile(prType: prType, record: prs[prType]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrTile extends StatelessWidget {
  final PrType prType;
  final PersonalRecord? record;

  const _PrTile({required this.prType, this.record});

  IconData get _icon => switch (prType) {
        PrType.fastest500m => Icons.speed,
        PrType.fastest2k => Icons.timer,
        PrType.fastest5k => Icons.timer,
        PrType.fastest6k => Icons.timer,
        PrType.fastest10k => Icons.timer,
        PrType.fastestHalfMarathon => Icons.directions_run,
        PrType.fastestMarathon => Icons.directions_run,
        PrType.highestFtp => Icons.bolt,
        PrType.longestDistance => Icons.straighten,
      };

  String _formatValue() {
    if (record == null) return '--:--';
    final v = record!.value;
    return switch (prType) {
      PrType.highestFtp => wattsToPaceStringNoTenths(v),
      PrType.longestDistance => formatDistanceKm(v),
      _ => '${formatPace(v)}/500m',
    };
  }

  String? _formatSubValue() {
    if (record == null) return null;
    final v = record!.value;
    return switch (prType) {
      PrType.highestFtp => '${v}W',
      PrType.longestDistance => null,
      _ => null,
    };
  }

  String? _formatDate() {
    if (record == null) return null;
    final dt = record!.achievedAt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isEarned = record != null;
    final theme = Theme.of(context);
    final dateStr = _formatDate();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            _icon,
            size: 20,
            color: isEarned
                ? RowCraftTheme.primaryBlue
                : RowCraftTheme.subtleGrey.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prType.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isEarned
                        ? RowCraftTheme.metricWhite
                        : RowCraftTheme.subtleGrey,
                  ),
                ),
                if (dateStr != null)
                  Text(
                    dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: RowCraftTheme.subtleGrey,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatValue(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isEarned
                      ? RowCraftTheme.metricWhite
                      : RowCraftTheme.subtleGrey.withValues(alpha: 0.5),
                ),
              ),
              if (_formatSubValue() case final subValue?)
                Text(
                  subValue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: RowCraftTheme.subtleGrey,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Achievements
// ---------------------------------------------------------------------------

class _AchievementsSection extends ConsumerWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementListProvider);
    final theme = Theme.of(context);

    // Single pass: build earned set + highest threshold per type
    final earned = <(AchievementType, int)>{};
    final highest = <AchievementType, int>{};
    for (final a in achievements) {
      earned.add((a.achievementType, a.threshold));
      final prev = highest[a.achievementType];
      if (prev == null || a.threshold > prev) {
        highest[a.achievementType] = a.threshold;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final type in AchievementType.values) ...[
          _AchievementCategoryCard(
            type: type,
            earned: earned,
            highestEarnedThreshold: highest[type],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AchievementCategoryCard extends StatelessWidget {
  final AchievementType type;
  final Set<(AchievementType, int)> earned;
  final int? highestEarnedThreshold;

  const _AchievementCategoryCard({
    required this.type,
    required this.earned,
    this.highestEarnedThreshold,
  });

  IconData get _icon => switch (type) {
        AchievementType.totalDistance => Icons.straighten,
        AchievementType.workoutCount => Icons.fitness_center,
        AchievementType.planCompleted => Icons.calendar_month,
        AchievementType.streakDays => Icons.local_fire_department,
      };

  Color get _color => switch (type) {
        AchievementType.totalDistance => RowCraftTheme.primaryBlue,
        AchievementType.workoutCount => RowCraftTheme.successGreen,
        AchievementType.planCompleted => RowCraftTheme.accentTeal,
        AchievementType.streakDays => RowCraftTheme.warningAmber,
      };

  String _formatThreshold(int threshold) => switch (type) {
        AchievementType.totalDistance => formatDistanceShort(threshold),
        AchievementType.workoutCount => '$threshold',
        AchievementType.planCompleted => '$threshold',
        AchievementType.streakDays => '${threshold}d',
      };

  String? get _progressText {
    final thresholds = type.thresholds;
    final nextIdx = highestEarnedThreshold == null
        ? 0
        : thresholds.indexOf(highestEarnedThreshold!) + 1;
    if (nextIdx >= thresholds.length) return null;
    final next = thresholds[nextIdx];
    final current = highestEarnedThreshold ?? 0;
    return '${_formatThreshold(current)} / ${_formatThreshold(next)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, size: 20, color: _color),
                const SizedBox(width: 8),
                Text(type.label, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final threshold in type.thresholds)
                  _BadgeChip(
                    label: _formatThreshold(threshold),
                    isEarned: earned.contains((type, threshold)),
                    color: _color,
                  ),
              ],
            ),
            if (_progressText != null) ...[
              const SizedBox(height: 10),
              Text(
                _progressText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RowCraftTheme.subtleGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final bool isEarned;
  final Color color;

  const _BadgeChip({
    required this.label,
    required this.isEarned,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEarned
                ? color.withValues(alpha: 0.2)
                : RowCraftTheme.surfaceContainer,
            border: isEarned
                ? Border.all(color: color, width: 2)
                : Border.all(
                    color: RowCraftTheme.subtleGrey.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          child: Center(
            child: Icon(
              Icons.emoji_events,
              size: 20,
              color: isEarned
                  ? color
                  : RowCraftTheme.subtleGrey.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isEarned
                ? RowCraftTheme.metricWhite
                : RowCraftTheme.subtleGrey.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
