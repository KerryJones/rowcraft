import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../utils/hr_zones.dart';

/// Multi-section donut showing actual time-in-zone distribution for a segment.
///
/// `timeInZone` is `{zone: seconds}` for zones 1–5. If empty, renders a thin
/// grey ring as a no-data placeholder.
class HrZoneDonut extends StatelessWidget {
  final Map<int, double> timeInZone;
  final double size;
  final double strokeWidth;

  const HrZoneDonut({
    super.key,
    required this.timeInZone,
    this.size = 22,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final entries = timeInZone.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: RowCraftTheme.subtleGrey.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: (size / 2) - strokeWidth,
          startDegreeOffset: -90,
          sections: entries.map((e) {
            return PieChartSectionData(
              value: e.value,
              color: zoneColor(e.key),
              radius: strokeWidth,
              showTitle: false,
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Single-color target ring (no chart). Used in pre-workout / planning where
/// no actual HR data exists yet.
class HrZoneTargetRing extends StatelessWidget {
  final int? targetZone;
  final double size;
  final double strokeWidth;

  const HrZoneTargetRing({
    super.key,
    required this.targetZone,
    this.size = 22,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final color = targetZone != null
        ? zoneColor(targetZone!)
        : RowCraftTheme.subtleGrey.withValues(alpha: 0.4);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: strokeWidth),
      ),
    );
  }
}
