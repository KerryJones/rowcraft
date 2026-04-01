import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/workout_segment.dart';
import '../utils/workout_utils.dart';

/// Displays a 1-3 flame difficulty indicator.
/// Active flames are colored (green/amber/red), inactive are dimmed.
class DifficultyIndicator extends StatelessWidget {
  final int level;
  final double size;

  const DifficultyIndicator({
    super.key,
    required this.level,
    this.size = 16,
  });

  /// Create from workout segments (auto-calculates difficulty).
  factory DifficultyIndicator.fromSegments({
    Key? key,
    required List<WorkoutSegment> segments,
    double size = 16,
  }) {
    return DifficultyIndicator(
      key: key,
      level: computeDifficultyLevel(segments),
      size: size,
    );
  }

  /// Map plan difficulty string to level.
  static int levelFromDifficulty(String difficulty) {
    return switch (difficulty) {
      'beginner' => 1,
      'intermediate' => 2,
      'advanced' => 3,
      _ => 2,
    };
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = switch (level) {
      1 => RowCraftTheme.successGreen,
      2 => RowCraftTheme.warningAmber,
      _ => RowCraftTheme.errorRose,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i < level;
        return Padding(
          padding: EdgeInsets.only(right: i < 2 ? 2 : 0),
          child: Icon(
            Icons.local_fire_department,
            size: size,
            color: isActive
                ? activeColor
                : RowCraftTheme.surfaceContainerHigh,
          ),
        );
      }),
    );
  }
}
