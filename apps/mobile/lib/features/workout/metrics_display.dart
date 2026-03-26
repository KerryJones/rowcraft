import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Size variants for the metric display.
enum MetricSize { hero, large, medium, small }

/// Reusable large metric display widget.
///
/// Shows a value + label + optional target range indicator.
/// When [targetMin] and [targetMax] are provided along with [currentValue],
/// the widget shows a color-coded indicator for whether the current value
/// is within, above, or below the target range.
class MetricsDisplay extends StatelessWidget {
  final String value;
  final String label;
  final MetricSize size;
  final double? targetMin;
  final double? targetMax;
  final double? currentValue;

  const MetricsDisplay({
    super.key,
    required this.value,
    required this.label,
    this.size = MetricSize.medium,
    this.targetMin,
    this.targetMax,
    this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final valueStyle = switch (size) {
      MetricSize.hero => theme.textTheme.displayLarge,
      MetricSize.large => theme.textTheme.displayMedium,
      MetricSize.medium => theme.textTheme.displaySmall,
      MetricSize.small => theme.textTheme.headlineLarge,
    };

    final labelStyle = switch (size) {
      MetricSize.hero || MetricSize.large => theme.textTheme.labelLarge,
      MetricSize.medium || MetricSize.small => theme.textTheme.labelMedium,
    };

    // Determine target indicator color
    Color? targetColor;
    if (targetMin != null && targetMax != null && currentValue != null) {
      targetColor = _getTargetColor(currentValue!, targetMin!, targetMax!);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Value with optional target color glow
        Text(
          value,
          style: valueStyle?.copyWith(
            color: targetColor ?? RowCraftTheme.metricWhite,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 2),

        // Label
        Text(
          label,
          style: labelStyle,
          textAlign: TextAlign.center,
        ),

        // Target range indicator bar
        if (targetMin != null && targetMax != null) ...[
          const SizedBox(height: 6),
          _TargetRangeBar(
            min: targetMin!,
            max: targetMax!,
            current: currentValue,
          ),
        ],
      ],
    );
  }

  /// Determine the color based on whether the current value is in range.
  /// For pace (split), LOWER is BETTER, so being below min is good,
  /// and above max is bad. We treat this generically here.
  Color _getTargetColor(double current, double min, double max) {
    if (current >= min && current <= max) {
      return RowCraftTheme.successGreen;
    } else if (current < min) {
      // Below target range — could be good (pace) or bad (SR)
      return RowCraftTheme.segmentWarmup;
    } else {
      // Above target range
      return RowCraftTheme.warningAmber;
    }
  }
}

/// A small horizontal bar showing the target range and current position.
class _TargetRangeBar extends StatelessWidget {
  final double min;
  final double max;
  final double? current;

  const _TargetRangeBar({
    required this.min,
    required this.max,
    this.current,
  });

  @override
  Widget build(BuildContext context) {
    // Show a simple colored bar with the range
    final range = max - min;
    if (range <= 0) return const SizedBox.shrink();

    // Expand the display range by 50% on each side
    final displayMin = min - range * 0.5;
    final displayMax = max + range * 0.5;
    final displayRange = displayMax - displayMin;

    return SizedBox(
      width: 80,
      height: 8,
      child: CustomPaint(
        painter: _TargetRangePainter(
          min: min,
          max: max,
          current: current,
          displayMin: displayMin,
          displayRange: displayRange,
        ),
      ),
    );
  }
}

class _TargetRangePainter extends CustomPainter {
  final double min;
  final double max;
  final double? current;
  final double displayMin;
  final double displayRange;

  _TargetRangePainter({
    required this.min,
    required this.max,
    this.current,
    required this.displayMin,
    required this.displayRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = RowCraftTheme.surfaceContainerHigh
      ..style = PaintingStyle.fill;

    final rangePaint = Paint()
      ..color = RowCraftTheme.successGreen.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    // Target range zone
    final rangeLeft = ((min - displayMin) / displayRange * size.width)
        .clamp(0.0, size.width);
    final rangeRight = ((max - displayMin) / displayRange * size.width)
        .clamp(0.0, size.width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(rangeLeft, 0, rangeRight, size.height),
        const Radius.circular(4),
      ),
      rangePaint,
    );

    // Current value indicator
    if (current != null) {
      final x = ((current! - displayMin) / displayRange * size.width)
          .clamp(2.0, size.width - 2);

      final isInRange = current! >= min && current! <= max;
      final indicatorPaint = Paint()
        ..color = isInRange ? RowCraftTheme.successGreen : RowCraftTheme.warningAmber
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, size.height / 2),
        3,
        indicatorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TargetRangePainter oldDelegate) {
    return current != oldDelegate.current;
  }
}
