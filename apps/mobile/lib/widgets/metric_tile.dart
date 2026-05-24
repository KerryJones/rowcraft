import 'package:flutter/material.dart';

import '../app/theme.dart';

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
          color: RowCraftTheme.subtleGrey,
        );
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: RowCraftTheme.subtleGrey),
                const SizedBox(width: 4),
              ],
              Text(label, style: labelStyle),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
                  color: RowCraftTheme.metricWhite,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
