import 'dart:math';

import 'package:flutter/material.dart';

import '../models/workout_segment.dart';
import '../utils/pace_utils.dart';
import '../utils/segment_color.dart';

/// Segment bar chart showing intensity (height) and duration (width).
/// Replicates the web WorkoutGraph component.
class WorkoutGraph extends StatelessWidget {
  final List<WorkoutSegment> segments;
  final double height;
  final int ftpWatts;

  const WorkoutGraph({
    super.key,
    required this.segments,
    this.height = 80,
    this.ftpWatts = kDefaultFtpWatts,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return SizedBox(height: height);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _GraphPainter(segments: segments, ftpWatts: ftpWatts),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<WorkoutSegment> segments;
  final int ftpWatts;

  static const _barGap = 1.5;
  static const _minBarHeightFraction = 0.15;
  static const _defaultPaceMin = 1000.0;
  static const _defaultPaceMax = 1800.0;

  _GraphPainter({required this.segments, required this.ftpWatts});

  @override
  void paint(Canvas canvas, Size size) {
    final expanded = _expandSegments(segments);
    if (expanded.isEmpty) return;

    final durations = expanded.map((s) => _effectiveDuration(s, ftpWatts)).toList();
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
      final double? pace;
      if (seg.targetIntensity != null) {
        final resolved = resolveIntensityToPace(
          seg.targetIntensity!.min,
          seg.targetIntensity!.max,
          ftpWatts,
        );
        pace = resolved.paceMid.toDouble();
      } else {
        pace = null;
      }
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
  bool shouldRepaint(_GraphPainter old) =>
      old.segments != segments || old.ftpWatts != ftpWatts;

  /// Return segments as-is (segments are already individual).
  static List<WorkoutSegment> _expandSegments(List<WorkoutSegment> segments) {
    return segments;
  }

  static double _effectiveDuration(WorkoutSegment seg, int ftpWatts) {
    if (seg.durationType == DurationType.time) return seg.durationValue;
    if (seg.durationType == DurationType.distance) {
      final double pacePerMeter;
      if (seg.targetIntensity != null) {
        final resolved = resolveIntensityToPace(
          seg.targetIntensity!.min,
          seg.targetIntensity!.max,
          ftpWatts,
        );
        pacePerMeter = (resolved.paceMid / 10) / 500;
      } else {
        pacePerMeter = 0.24;
      }
      return seg.durationValue * pacePerMeter;
    }
    // Calories: estimate ~15 cal/min (matches web fallback)
    return (seg.durationValue / 15) * 60;
  }

  (double, double) _getPaceRange(List<WorkoutSegment> segments) {
    final paces = <double>[];
    for (final seg in segments) {
      if (seg.targetIntensity != null) {
        final resolved = resolveIntensityToPace(
          seg.targetIntensity!.min,
          seg.targetIntensity!.max,
          ftpWatts,
        );
        paces.add(resolved.paceMid.toDouble());
      }
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
