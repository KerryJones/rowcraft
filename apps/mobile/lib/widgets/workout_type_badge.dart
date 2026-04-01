import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/workout.dart';

class WorkoutTypeBadge extends StatelessWidget {
  final WorkoutType type;

  const WorkoutTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      WorkoutType.singleDistance => ('Distance', RowCraftTheme.segmentWork),
      WorkoutType.singleTime => ('Time', RowCraftTheme.segmentWarmup),
      WorkoutType.intervals => ('Intervals', RowCraftTheme.warningAmber),
      WorkoutType.variableIntervals =>
        ('Variable', RowCraftTheme.segmentCooldown),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
