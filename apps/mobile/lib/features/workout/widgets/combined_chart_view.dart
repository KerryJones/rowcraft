import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/workout_segment.dart';
import '../../../models/workout_time_sample.dart';
import '../../../utils/pace_utils.dart' show formatPace;
import '../../../utils/segment_color.dart';
import '../../../utils/workout_utils.dart' show formatDuration;

/// Pace bars (colored by segment zone) with HR line overlay. Shared between
/// the post-workout summary and the history detail screen.
class CombinedChartView extends StatelessWidget {
  final List<WorkoutTimeSample> samples;
  final List<WorkoutSegment> segments;
  final double height;

  const CombinedChartView({
    super.key,
    required this.samples,
    required this.segments,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final hasHrData =
        samples.any((s) => s.heartRate != null && s.heartRate! > 0);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: CombinedChartPainter(
          samples: samples,
          segments: segments,
          hasHrData: hasHrData,
        ),
      ),
    );
  }
}

class CombinedChartPainter extends CustomPainter {
  final List<WorkoutTimeSample> samples;
  final List<WorkoutSegment> segments;
  final bool hasHrData;

  CombinedChartPainter({
    required this.samples,
    required this.segments,
    required this.hasHrData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    const leftPad = 44.0;
    final rightPad = hasHrData ? 36.0 : 8.0;
    const topPad = 8.0;
    const bottomPad = 20.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final maxTime = samples.last.timestamp.inSeconds.toDouble();
    if (maxTime <= 0) return;

    // Pace range (inverted: lower pace = higher on chart)
    final paces = samples.where((s) => s.pace > 0).map((s) => s.pace);
    if (paces.isEmpty) return;
    final minPace = paces.reduce(math.min).toDouble();
    final maxPace = paces.reduce(math.max).toDouble();
    final paceRange = maxPace - minPace;
    final padAmount = paceRange == 0 ? 200.0 : paceRange * 0.15;
    final displayMinPace = minPace - padAmount;
    final displayMaxPace = maxPace + padAmount;
    final displayPaceRange = displayMaxPace - displayMinPace;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      Paint()..color = RowCraftTheme.surfaceContainer,
    );

    // Draw pace as colored vertical bars (like Zwift's bar chart style)
    final barWidth = math.max(1.0, chartWidth / samples.length);
    for (final sample in samples) {
      if (sample.pace <= 0) continue;
      final x = leftPad + (sample.timestamp.inSeconds / maxTime) * chartWidth;
      final yNorm = (sample.pace - displayMinPace) / displayPaceRange;
      final y = topPad + yNorm * chartHeight;
      final barBottom = topPad + chartHeight;

      // Color by segment zone
      final seg = sample.segmentIndex < segments.length
          ? segments[sample.segmentIndex]
          : null;
      final color = seg != null
          ? segmentDisplayColor(seg)
          : RowCraftTheme.primaryBlue;

      canvas.drawRect(
        Rect.fromLTRB(x, y, x + barWidth, barBottom),
        Paint()..color = color.withValues(alpha: 0.6),
      );
    }

    // Segment boundary lines
    int prevSegIndex = -1;
    for (final sample in samples) {
      if (sample.segmentIndex != prevSegIndex && prevSegIndex >= 0) {
        final x = leftPad + (sample.timestamp.inSeconds / maxTime) * chartWidth;
        canvas.drawLine(
          Offset(x, topPad),
          Offset(x, topPad + chartHeight),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..strokeWidth = 1,
        );
      }
      prevSegIndex = sample.segmentIndex;
    }

    // Y-axis labels (pace, left side)
    final labelStyle = GoogleFonts.jetBrainsMono(
      fontSize: 9,
      color: RowCraftTheme.subtleGrey,
    );
    for (var i = 0; i < 3; i++) {
      final frac = i / 2.0;
      final pace = displayMinPace + frac * displayPaceRange;
      final y = topPad + frac * chartHeight;
      final tp = TextPainter(
        text: TextSpan(
          text: formatPace(pace.round().clamp(1, 9999)),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    // X-axis labels (time)
    for (var i = 0; i < 3; i++) {
      final frac = i / 2.0;
      final sec = (maxTime * frac).round();
      final x = leftPad + frac * chartWidth;
      final label = formatDuration(sec);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, topPad + chartHeight + 4));
    }

    // HR line overlay (red line on top of pace bars)
    if (hasHrData) {
      final hrSamples = samples
          .where((s) => s.heartRate != null && s.heartRate! > 0)
          .toList();
      if (hrSamples.isNotEmpty) {
        final hrValues = hrSamples.map((s) => s.heartRate!);
        final minHr = hrValues.reduce(math.min).toDouble();
        final maxHrVal = hrValues.reduce(math.max).toDouble();
        final hrRange = maxHrVal - minHr;
        final hrPad = hrRange == 0 ? 20.0 : hrRange * 0.15;
        final displayMinHr = (minHr - hrPad).clamp(0.0, double.infinity);
        final displayMaxHr = maxHrVal + hrPad;
        final displayHrRange = displayMaxHr - displayMinHr;

        // HR line
        final hrPath = Path();
        var started = false;
        for (final sample in hrSamples) {
          final x =
              leftPad + (sample.timestamp.inSeconds / maxTime) * chartWidth;
          final yNorm =
              1.0 - (sample.heartRate! - displayMinHr) / displayHrRange;
          final y = topPad + yNorm * chartHeight;
          if (!started) {
            hrPath.moveTo(x, y);
            started = true;
          } else {
            hrPath.lineTo(x, y);
          }
        }

        canvas.drawPath(
          hrPath,
          Paint()
            ..color = RowCraftTheme.errorRose
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round,
        );

        // HR Y-axis labels (right side)
        final hrLabelStyle = GoogleFonts.jetBrainsMono(
          fontSize: 9,
          color: RowCraftTheme.errorRose.withValues(alpha: 0.7),
        );
        for (var i = 0; i < 3; i++) {
          final frac = i / 2.0;
          final bpm = displayMinHr + frac * displayHrRange;
          final y = topPad + (1.0 - frac) * chartHeight;
          final tp = TextPainter(
            text: TextSpan(text: '${bpm.round()}', style: hrLabelStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            Offset(size.width - tp.width - 2, y - tp.height / 2),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(CombinedChartPainter old) =>
      old.samples != samples ||
      old.hasHrData != hasHrData ||
      old.segments != segments;
}
