import 'dart:math';

import 'package:flutter/material.dart';

import '../models/workout_segment.dart';
import '../utils/segment_color.dart';

/// Segment bar chart showing intensity (height) and duration (width).
/// Replicates the web WorkoutGraph component.
class WorkoutGraph extends StatelessWidget {
  final List<WorkoutSegment> segments;
  final double height;

  const WorkoutGraph({
    super.key,
    required this.segments,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return SizedBox(height: height);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _GraphPainter(segments: segments),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<WorkoutSegment> segments;

  static const _barGap = 1.5;
  static const _minBarHeightFraction = 0.15;
  static const _defaultPaceMin = 1000.0;
  static const _defaultPaceMax = 1800.0;

  _GraphPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final expanded = _expandSegments(segments);
    if (expanded.isEmpty) return;

    final durations = expanded.map(_effectiveDuration).toList();
    final totalDuration = durations.fold(0.0, (a, b) => a + b);
    if (totalDuration <= 0) return;

    final (paceMin, paceMax) = _getPaceRange(expanded);
    final barCount = expanded.length;
    final totalGap = _barGap * (barCount - 1);
    final availableWidth = size.width - totalGap;

    var x = 0.0;
    for (var i = 0; i < expanded.length; i++) {
      final seg = expanded[i];
      final barWidth = max(2.0, (durations[i] / totalDuration) * availableWidth);
      final pace = seg.targetSplit?.min;
      final heightFraction = _paceToHeight(pace, paceMin, paceMax);
      final barHeight = max(4.0, heightFraction * size.height);

      final paint = Paint()..color = segmentDisplayColor(seg);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);

      x += barWidth + _barGap;
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.segments != segments;

  /// Return segments as-is (segments are already individual).
  static List<WorkoutSegment> _expandSegments(List<WorkoutSegment> segments) {
    return segments;
  }

  static double _effectiveDuration(WorkoutSegment seg) {
    if (seg.durationType == DurationType.time) return seg.durationValue;
    if (seg.durationType == DurationType.distance) {
      final pacePerMeter = seg.targetSplit != null
          ? (seg.targetSplit!.min / 10) / 500
          : 0.24;
      return seg.durationValue * pacePerMeter;
    }
    // Calories: estimate ~15 cal/min (matches web fallback)
    return (seg.durationValue / 15) * 60;
  }

  static (double, double) _getPaceRange(List<WorkoutSegment> segments) {
    final paces = <double>[];
    for (final seg in segments) {
      if (seg.targetSplit != null) paces.add(seg.targetSplit!.min);
    }
    if (paces.isEmpty) return (_defaultPaceMin, _defaultPaceMax);
    final minP = paces.reduce(min);
    final maxP = paces.reduce(max);
    final range = maxP - minP;
    final padding = range == 0 ? 200.0 : range * 0.1;
    return (max(0, minP - padding), maxP + padding);
  }

  static double _paceToHeight(double? pace, double paceMin, double paceMax) {
    if (pace == null) return _minBarHeightFraction;
    final range = paceMax - paceMin;
    if (range == 0) return 0.7;
    final normalized = 1 - (pace - paceMin) / range;
    return _minBarHeightFraction + normalized * (1 - _minBarHeightFraction);
  }

}
