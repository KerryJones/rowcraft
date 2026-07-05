// Segment profile graph shared by the classic and compact screens.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../models/workout_segment.dart';
import '../../../models/workout_time_sample.dart';
import '../../../utils/pace_utils.dart';
import '../../../utils/workout_utils.dart';
import '../../../utils/segment_color.dart';
import '../workout_engine.dart';
import '../workout_provider.dart';

// ---------------------------------------------------------------------------
// Workout Profile Graph (64px) — CustomPaint
// ---------------------------------------------------------------------------

class WorkoutProfileGraph extends StatelessWidget {
  final WorkoutSessionState session;
  final double height;
  /// When true, the painter draws axis labels noticeably bigger and bolder so
  /// the rower can read them at arm's length in landscape.
  final bool landscapePhone;

  const WorkoutProfileGraph({
    super.key,
    required this.session,
    this.height = 64,
    this.landscapePhone = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _WorkoutProfilePainter(
          segments: session.expandedSegments,
          currentIndex: session.engineState.currentSegmentIndex,
          segmentProgress: session.engineState.segmentProgress,
          phase: session.engineState.phase,
          ftpWatts: session.ftpWatts,
          timeSamples: session.timeSamples,
          landscapePhone: landscapePhone,
        ),
      ),
    );
  }
}

class _WorkoutProfilePainter extends CustomPainter {
  final List<WorkoutSegment> segments;
  final int currentIndex;
  final double segmentProgress;
  final WorkoutPhase phase;
  final int ftpWatts;
  final List<WorkoutTimeSample>? timeSamples;
  final bool landscapePhone;

  _WorkoutProfilePainter({
    required this.segments,
    required this.currentIndex,
    required this.segmentProgress,
    required this.phase,
    required this.ftpWatts,
    this.timeSamples,
    this.landscapePhone = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    const barGap = 1.5;
    const minHeightFraction = 0.15;
    const leftPad = 44.0;
    var hasHrData = false;
    int hrMin = 999, hrMax = 0;
    if (timeSamples != null) {
      for (final s in timeSamples!) {
        if (s.heartRate == null || s.heartRate! <= 0) continue;
        final si = s.segmentIndex;
        if (si < 0 || si >= segments.length) continue;
        hasHrData = true;
        if (s.heartRate! < hrMin) hrMin = s.heartRate!;
        if (s.heartRate! > hrMax) hrMax = s.heartRate!;
      }
    }
    final rightPad = hasHrData ? 36.0 : 8.0;

    final durations = segments.map((s) => effectiveDuration(s, ftpWatts)).toList();
    final totalDuration = durations.fold<double>(0, (a, b) => a + b);
    if (totalDuration <= 0) return;

    // Absolute pace range anchored to FTP (40%-130% intensity).
    // This prevents tiny pace differences from looking like huge swings.
    final paceMin = intensityToPaceTenths(130, ftpWatts).toDouble(); // fastest (race pace)
    final paceMax = intensityToPaceTenths(40, ftpWatts).toDouble();  // slowest (very easy)

    double paceToHeight(double? pace) {
      if (pace == null) return minHeightFraction;
      final range = paceMax - paceMin;
      if (range == 0) return 0.7;
      final normalized = 1 - (pace - paceMin) / range;
      final heightFraction =
          minHeightFraction + normalized * (1 - minHeightFraction);
      // Segments outside the 40%-130% anchor (deep warmup, all-out sprint)
      // would otherwise render taller than the canvas or with a negative
      // height — pin them to the chart bounds instead.
      return heightFraction.clamp(minHeightFraction, 1.0);
    }

    final totalGapWidth = barGap * (segments.length - 1);
    final availableWidth = size.width - leftPad - rightPad - totalGapWidth;

    // Draw bars
    var x = leftPad;
    double playheadX = 0;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final widthFraction = durations[i] / totalDuration;
      final barWidth = math.max(2.0, widthFraction * availableWidth);
      final resolved = resolveSegmentTargetPace(seg, ftpWatts);
      final double? avgPace = resolved > 0 ? resolved.toDouble() : null;
      final heightFraction = paceToHeight(avgPace);
      final barHeight = heightFraction * size.height;
      final barY = size.height - barHeight;

      final color = segmentDisplayColor(seg);
      final isCompleted = i < currentIndex;
      final isCurrent = i == currentIndex;

      // Determine opacity
      double opacity;
      if (isCompleted) {
        opacity = 0.35;
      } else if (isCurrent) {
        opacity = 1.0;
      } else {
        opacity = 0.65;
      }

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, barY, barWidth, barHeight),
        const Radius.circular(2),
      );

      // Fill
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(barRect, paint);

      // Current segment border
      if (isCurrent && phase != WorkoutPhase.idle) {
        final borderPaint = Paint()
          ..color = RowCraftTheme.metricWhite.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(barRect, borderPaint);

        // Playhead position within current bar
        playheadX = x + segmentProgress * barWidth;
      }

      x += barWidth + barGap;
    }

    // Y-axis pace reference lines and labels (matching summary chart style)
    {
      final gridPaint = Paint()
        ..color = RowCraftTheme.subtleGrey.withValues(alpha: 0.15)
        ..strokeWidth = 0.5;
      final paceRange = paceMax - paceMin;
      final labelStyle = GoogleFonts.jetBrainsMono(
        fontSize: landscapePhone ? 14 : 9,
        fontWeight: landscapePhone ? FontWeight.w700 : FontWeight.w400,
        color: RowCraftTheme.subtleGrey,
      );
      if (paceRange > 0) {
        // Draw 3 evenly spaced labels (matching summary chart)
        for (var i = 0; i < 3; i++) {
          final frac = i / 2.0;
          final pace = paceMin + frac * paceRange;
          final normalized = 1 - (pace - paceMin) / paceRange;
          final heightFrac = minHeightFraction + normalized * (1 - minHeightFraction);
          final y = size.height - heightFrac * size.height;
          // Grid line across chart area
          canvas.drawLine(
            Offset(leftPad, y),
            Offset(size.width - rightPad, y),
            gridPaint,
          );
          // Pace label on left
          final tp = TextPainter(
            text: TextSpan(
              text: formatPace(pace.round().clamp(1, 9999)),
              style: labelStyle,
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(2, (y - tp.height / 2).clamp(0.0, size.height - tp.height)));
        }
      }

      // HR Y-axis labels on right side (using same coordinate space as pace bars)
      if (hasHrData && hrMax > hrMin) {
        final hrLabelStyle = GoogleFonts.jetBrainsMono(
          fontSize: landscapePhone ? 14 : 9,
          fontWeight: landscapePhone ? FontWeight.w700 : FontWeight.w400,
          color: RowCraftTheme.errorRose.withValues(alpha: 0.7),
        );
        for (var i = 0; i < 3; i++) {
          final frac = i / 2.0;
          final bpm = hrMax - frac * (hrMax - hrMin);
          // Map to same coordinate space as pace bars (minHeightFraction → 1.0)
          final hrNorm = (bpm - hrMin) / (hrMax - hrMin); // 1.0 at hrMax, 0.0 at hrMin
          final heightFrac = minHeightFraction + hrNorm * (1 - minHeightFraction);
          final y = size.height - heightFrac * size.height;
          final tp = TextPainter(
            text: TextSpan(
              text: '${bpm.round()}',
              style: hrLabelStyle,
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(size.width - tp.width - 2, (y - tp.height / 2).clamp(0.0, size.height - tp.height)));
        }
      }
    }

    // Draw pace tracking line (white polyline showing actual pace vs target)
    if (timeSamples != null && timeSamples!.isNotEmpty) {
      // Build segment X-position lookup: for each segment, store its start X and width.
      final segStarts = <double>[];
      final segWidths = <double>[];
      var sx = leftPad;
      for (var i = 0; i < segments.length; i++) {
        segStarts.add(sx);
        final w = math.max(2.0, (durations[i] / totalDuration) * availableWidth);
        segWidths.add(w);
        sx += w + barGap;
      }

      // Build first-timestamp per segment for X positioning.
      // Use planned duration (not actual timestamp range) as the X denominator
      // so the dot moves proportionally through each bar as time elapses,
      // instead of jumping to the right edge and backfilling.
      final segFirstTs = List<double>.filled(segments.length, 0);
      final segSeen = List<bool>.filled(segments.length, false);
      for (final sample in timeSamples!) {
        final si = sample.segmentIndex;
        if (si < 0 || si >= segments.length) continue;
        if (!segSeen[si]) {
          segFirstTs[si] = sample.timestamp.inSeconds.toDouble();
          segSeen[si] = true;
        }
      }

      final pacePath = Path();
      var started = false;
      final paceRange = paceMax - paceMin;

      for (final sample in timeSamples!) {
        if (sample.pace <= 0) continue;
        final si = sample.segmentIndex;
        if (si < 0 || si >= segments.length) continue;
        // PM5 reports pace ~0 during rest, so the pace line skips rest segments.
        // (The HR overlay below intentionally does not — HR is meaningful during recovery.)
        if (segments[si].isRest) {
          started = false;
          continue;
        }

        // X: position within the segment bar using planned duration
        final segDurPlanned = durations[si];
        final double segFrac;
        if (segDurPlanned > 0) {
          segFrac = ((sample.timestamp.inSeconds - segFirstTs[si]) / segDurPlanned).clamp(0.0, 1.0);
        } else {
          segFrac = 0.5;
        }
        final px = segStarts[si] + segFrac * segWidths[si];

        // Y: map actual pace on the same scale as the bars
        double py;
        if (paceRange > 0) {
          final normalized = 1 - (sample.pace - paceMin) / paceRange;
          final heightFrac = minHeightFraction + normalized * (1 - minHeightFraction);
          py = size.height - heightFrac * size.height;
        } else {
          py = size.height * 0.5;
        }

        py = py.clamp(0.0, size.height);

        if (!started) {
          pacePath.moveTo(px, py);
          started = true;
        } else {
          pacePath.lineTo(px, py);
        }
      }

      canvas.drawPath(
        pacePath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      );

      // Draw HR polyline overlay (red line, matching summary chart)
      if (hasHrData && hrMax > hrMin) {
        final hrPath = Path();
        var hrStarted = false;
        for (final sample in timeSamples!) {
          if (sample.heartRate == null || sample.heartRate! <= 0) continue;
          final si = sample.segmentIndex;
          if (si < 0 || si >= segments.length) continue;

          final segDurPlanned = durations[si];
          final segFrac = segDurPlanned > 0
              ? ((sample.timestamp.inSeconds - segFirstTs[si]) / segDurPlanned).clamp(0.0, 1.0)
              : 0.5;
          final hx = segStarts[si] + segFrac * segWidths[si];

          final hrNorm = (sample.heartRate! - hrMin) / (hrMax - hrMin);
          final heightFrac = minHeightFraction + hrNorm * (1 - minHeightFraction);
          final hy = (size.height - heightFrac * size.height).clamp(0.0, size.height);

          if (!hrStarted) {
            hrPath.moveTo(hx, hy);
            hrStarted = true;
          } else {
            hrPath.lineTo(hx, hy);
          }
        }
        canvas.drawPath(
          hrPath,
          Paint()
            ..color = RowCraftTheme.errorRose.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeJoin = StrokeJoin.round,
        );
      }

    }

    // X driven by engine segmentProgress (not pace samples) so the cursor
    // advances smoothly and stays visible even when actual pace is off-chart.
    if (phase != WorkoutPhase.idle &&
        phase != WorkoutPhase.finished &&
        phase != WorkoutPhase.structuredComplete) {
      final cursorX = math.max(playheadX, leftPad);
      const topY = 6.0;

      canvas.drawLine(
        Offset(cursorX, 4),
        Offset(cursorX, size.height - 4),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(
        Offset(cursorX, topY),
        7,
        Paint()..color = Colors.white.withValues(alpha: 0.20),
      );
      canvas.drawCircle(
        Offset(cursorX, topY),
        4,
        Paint()..color = RowCraftTheme.metricWhite,
      );
    }
  }

  @override
  bool shouldRepaint(_WorkoutProfilePainter old) {
    return old.segments != segments ||
        old.currentIndex != currentIndex ||
        (old.segmentProgress - segmentProgress).abs() > 0.005 ||
        old.phase != phase ||
        old.ftpWatts != ftpWatts ||
        old.timeSamples != timeSamples ||
        old.landscapePhone != landscapePhone;
  }
}
