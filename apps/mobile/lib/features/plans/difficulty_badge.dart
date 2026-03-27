import 'package:flutter/material.dart';

import '../../app/theme.dart';

class DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const DifficultyBadge({super.key, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (difficulty) {
      'beginner' => ('Beginner', RowCraftTheme.successGreen),
      'intermediate' => ('Intermediate', RowCraftTheme.warningAmber),
      'advanced' => ('Advanced', RowCraftTheme.errorRose),
      _ => (difficulty, RowCraftTheme.subtleGrey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
