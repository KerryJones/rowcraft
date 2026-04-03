import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../models/workout_result.dart';
import '../../models/workout_segment.dart';
import '../../models/workout_time_sample.dart';
import '../../services/c2_logbook_service.dart';
import 'workout_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Color _segmentColor(SegmentType type) {
  return switch (type) {
    SegmentType.work => RowCraftTheme.segmentWork,
    SegmentType.rest => RowCraftTheme.segmentRest,
    SegmentType.warmup => RowCraftTheme.segmentWarmup,
    SegmentType.cooldown => RowCraftTheme.segmentCooldown,
  };
}

String _formatPaceTenths(int tenths) {
  if (tenths == 0) return '--:--';
  final m = tenths ~/ 600;
  final r = tenths % 600;
  final s = r ~/ 10;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _formatDistance(double distance) {
  if (distance >= 1000) {
    return '${(distance / 1000).toStringAsFixed(1)}km';
  }
  return '${distance.toInt()}m';
}

Color _hrZoneColor(int bpm, {int maxHr = 190}) {
  if (bpm < (maxHr * 0.6).round()) return RowCraftTheme.hrZone1;
  if (bpm < (maxHr * 0.7).round()) return RowCraftTheme.hrZone2;
  if (bpm < (maxHr * 0.8).round()) return RowCraftTheme.hrZone3;
  if (bpm < (maxHr * 0.9).round()) return RowCraftTheme.hrZone4;
  return RowCraftTheme.hrZone5;
}

// ---------------------------------------------------------------------------
// WorkoutSummaryContent — shown inside WorkoutScreen when phase == finished
// ---------------------------------------------------------------------------

class WorkoutSummaryContent extends ConsumerStatefulWidget {
  const WorkoutSummaryContent({super.key});

  @override
  ConsumerState<WorkoutSummaryContent> createState() =>
      _WorkoutSummaryContentState();
}

class _WorkoutSummaryContentState extends ConsumerState<WorkoutSummaryContent> {
  bool _showSaveOverlay = false;
  Timer? _autoNavTimer;

  @override
  void dispose() {
    _autoNavTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final result = session.pendingResult;
    final pm5 = session.pm5Data;
    final timeSamples = session.timeSamples;
    final segments = session.expandedSegments;
    final splits = result?.splits ?? <SplitData>[];
    final maxHr = session.maxHeartRate ?? 190;

    // Stats from pendingResult, falling back to pm5Data
    final totalDistance = result?.totalDistance ?? pm5.distance;
    final totalTime = result?.totalTime ?? pm5.elapsedTime;
    final avgPace = result?.avgSplit ?? pm5.pace;
    final avgSR = result?.avgStrokeRate ?? pm5.strokeRate;
    final avgHR = result?.avgHeartRate ?? pm5.heartRate;
    final calories = result?.calories ?? pm5.calories;

    // Check if HR data exists in time samples
    final hasHrData = timeSamples != null &&
        timeSamples.any((s) => s.heartRate != null && s.heartRate! > 0);

    // Auto-navigate on save success
    if (session.saveProgress == SaveProgress.done && _autoNavTimer == null) {
      _autoNavTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) context.go('/');
      });
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Stats grid
              _StatsGrid(
                totalDistance: totalDistance,
                totalTime: totalTime,
                avgPace: avgPace,
                avgSR: avgSR,
                avgHR: avgHR,
                calories: calories,
              ),

              const SizedBox(height: 16),

              // Pace chart
              const _SectionHeader(title: 'PACE'),
              if (timeSamples != null && timeSamples.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 160,
                    child: CustomPaint(
                      size: const Size(double.infinity, 160),
                      painter: _PaceChartPainter(
                        samples: timeSamples,
                        segments: segments,
                      ),
                    ),
                  ),
                )
              else
                const _NoDataPlaceholder(label: 'No pace data'),

              const SizedBox(height: 20),

              // HR chart (only if HR data exists)
              if (hasHrData) ...[
                const _SectionHeader(title: 'HEART RATE'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 160,
                    child: CustomPaint(
                      size: const Size(double.infinity, 160),
                      painter: _HrChartPainter(
                        samples: timeSamples,
                        segments: segments,
                        maxHr: maxHr,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Per-segment table
              if (splits.isNotEmpty) ...[
                const _SectionHeader(title: 'SPLITS'),
                _SplitsTable(splits: splits, segments: segments),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),

        // Save/discard buttons at the bottom
        if (!_showSaveOverlay)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SaveDiscardBar(
              onSave: () {
                setState(() => _showSaveOverlay = true);
                ref.read(workoutSessionProvider.notifier).saveResult();
              },
              onDiscard: () => _showDiscardConfirmation(context),
            ),
          ),

        // Save progress overlay
        if (_showSaveOverlay)
          Positioned.fill(
            child: _SaveProgressOverlay(
              saveProgress: session.saveProgress,
              onRetry: () {
                ref.read(workoutSessionProvider.notifier).saveResult();
              },
            ),
          ),
      ],
    );
  }

  void _showDiscardConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RowCraftTheme.surfaceContainer,
        title: Text(
          'Discard workout?',
          style: GoogleFonts.inter(
            color: RowCraftTheme.metricWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This workout result will be permanently deleted.',
          style: GoogleFonts.inter(color: RowCraftTheme.subtleGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: RowCraftTheme.subtleGrey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(workoutSessionProvider.notifier).discardResult();
              context.go('/');
            },
            child: Text(
              'Discard',
              style: GoogleFonts.inter(
                color: RowCraftTheme.errorRose,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats Grid (2x3)
// ---------------------------------------------------------------------------

class _StatsGrid extends StatelessWidget {
  final double totalDistance;
  final Duration totalTime;
  final int avgPace;
  final int avgSR;
  final int? avgHR;
  final int calories;

  const _StatsGrid({
    required this.totalDistance,
    required this.totalTime,
    required this.avgPace,
    required this.avgSR,
    required this.avgHR,
    required this.calories,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'DISTANCE',
                  value: _formatDistance(totalDistance),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  label: 'TIME',
                  value: _formatDuration(totalTime),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  label: 'AVG PACE',
                  value: _formatPaceTenths(avgPace),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'AVG S/M',
                  value: '$avgSR',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  label: 'AVG HR',
                  value: avgHR != null ? '$avgHR' : '--',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  label: 'CALORIES',
                  value: '$calories',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: RowCraftTheme.metricWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: RowCraftTheme.subtleGrey,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: RowCraftTheme.subtleGrey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// No Data Placeholder
// ---------------------------------------------------------------------------

class _NoDataPlaceholder extends StatelessWidget {
  final String label;

  const _NoDataPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: RowCraftTheme.subtleGrey,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pace Chart (CustomPaint)
// ---------------------------------------------------------------------------

class _PaceChartPainter extends CustomPainter {
  final List<WorkoutTimeSample> samples;
  final List<WorkoutSegment> segments;

  _PaceChartPainter({required this.samples, required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    const leftPad = 44.0;
    const rightPad = 8.0;
    const topPad = 8.0;
    const bottomPad = 20.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final maxTime = samples.last.timestamp.inSeconds.toDouble();
    if (maxTime <= 0) return;

    // Compute pace range (inverted: lower pace = higher on chart)
    final paces = samples.where((s) => s.pace > 0).map((s) => s.pace);
    if (paces.isEmpty) return;
    final minPace = paces.reduce(math.min).toDouble();
    final maxPace = paces.reduce(math.max).toDouble();
    final paceRange = maxPace - minPace;
    final padAmount = paceRange == 0 ? 200.0 : paceRange * 0.15;
    final displayMin = minPace - padAmount;
    final displayMax = maxPace + padAmount;
    final displayRange = displayMax - displayMin;

    // Draw background
    final bgPaint = Paint()..color = RowCraftTheme.surfaceContainer;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      bgPaint,
    );

    // Draw segment boundary lines
    _drawSegmentBoundaries(
        canvas, size, leftPad, topPad, chartWidth, chartHeight, maxTime);

    // Draw Y-axis labels (pace values)
    _drawYAxisLabels(
        canvas, leftPad, topPad, chartHeight, displayMin, displayMax);

    // Draw X-axis labels (time)
    _drawXAxisLabels(
        canvas, size, leftPad, topPad, chartWidth, chartHeight, maxTime);

    // Draw pace line
    final path = Path();
    var started = false;
    for (final sample in samples) {
      if (sample.pace <= 0) continue;
      final x =
          leftPad + (sample.timestamp.inSeconds / maxTime) * chartWidth;
      // Inverted: lower pace (faster) = higher on chart
      final yNorm = 1.0 - (sample.pace - displayMin) / displayRange;
      final y = topPad + yNorm * chartHeight;
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = RowCraftTheme.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  void _drawSegmentBoundaries(Canvas canvas, Size size, double leftPad,
      double topPad, double chartWidth, double chartHeight, double maxTime) {
    // Build cumulative segment durations to find boundaries
    int prevSegIndex = -1;
    for (final sample in samples) {
      if (sample.segmentIndex != prevSegIndex && prevSegIndex >= 0) {
        final x =
            leftPad + (sample.timestamp.inSeconds / maxTime) * chartWidth;
        final segColor = prevSegIndex < segments.length
            ? _segmentColor(segments[prevSegIndex].type)
            : RowCraftTheme.subtleGrey;
        final paint = Paint()
          ..color = segColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawLine(
          Offset(x, topPad),
          Offset(x, topPad + chartHeight),
          paint,
        );
      }
      prevSegIndex = sample.segmentIndex;
    }
  }

  void _drawYAxisLabels(Canvas canvas, double leftPad, double topPad,
      double chartHeight, double displayMin, double displayMax) {
    final labelStyle = GoogleFonts.jetBrainsMono(
      fontSize: 9,
      color: RowCraftTheme.subtleGrey,
    );
    // Show 3 labels: top (fast/low pace), middle, bottom (slow/high pace)
    for (var i = 0; i < 3; i++) {
      final frac = i / 2.0;
      // Top = low pace (fast), bottom = high pace (slow)
      final pace = displayMax - frac * (displayMax - displayMin);
      final y = topPad + frac * chartHeight;
      final tp = TextPainter(
        text: TextSpan(text: _formatPaceTenths(pace.round().clamp(1, 9999)), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }
  }

  void _drawXAxisLabels(Canvas canvas, Size size, double leftPad,
      double topPad, double chartWidth, double chartHeight, double maxTime) {
    final labelStyle = GoogleFonts.jetBrainsMono(
      fontSize: 9,
      color: RowCraftTheme.subtleGrey,
    );
    // Show labels at 0, mid, end
    for (var i = 0; i < 3; i++) {
      final frac = i / 2.0;
      final sec = (maxTime * frac).round();
      final x = leftPad + frac * chartWidth;
      final label = _formatDuration(Duration(seconds: sec));
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, topPad + chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(_PaceChartPainter old) => old.samples != samples;
}

// ---------------------------------------------------------------------------
// HR Chart (CustomPaint)
// ---------------------------------------------------------------------------

class _HrChartPainter extends CustomPainter {
  final List<WorkoutTimeSample> samples;
  final List<WorkoutSegment> segments;
  final int maxHr;

  _HrChartPainter({
    required this.samples,
    required this.segments,
    required this.maxHr,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hrSamples =
        samples.where((s) => s.heartRate != null && s.heartRate! > 0).toList();
    if (hrSamples.isEmpty) return;

    const leftPad = 36.0;
    const rightPad = 8.0;
    const topPad = 8.0;
    const bottomPad = 20.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    final maxTime = samples.last.timestamp.inSeconds.toDouble();
    if (maxTime <= 0) return;

    final hrValues = hrSamples.map((s) => s.heartRate!);
    final minHr = hrValues.reduce(math.min).toDouble();
    final maxHrVal = hrValues.reduce(math.max).toDouble();
    final hrRange = maxHrVal - minHr;
    final padAmount = hrRange == 0 ? 20.0 : hrRange * 0.15;
    final displayMin = (minHr - padAmount).clamp(0.0, double.infinity);
    final displayMax = maxHrVal + padAmount;
    final displayRange = displayMax - displayMin;

    // Draw background
    final bgPaint = Paint()..color = RowCraftTheme.surfaceContainer;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(10),
      ),
      bgPaint,
    );

    // Draw segment boundaries
    int prevSegIndex = -1;
    for (final sample in samples) {
      if (sample.segmentIndex != prevSegIndex && prevSegIndex >= 0) {
        final x =
            leftPad + (sample.timestamp.inSeconds / maxTime) * chartWidth;
        final segColor = prevSegIndex < segments.length
            ? _segmentColor(segments[prevSegIndex].type)
            : RowCraftTheme.subtleGrey;
        final paint = Paint()
          ..color = segColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawLine(
          Offset(x, topPad),
          Offset(x, topPad + chartHeight),
          paint,
        );
      }
      prevSegIndex = sample.segmentIndex;
    }

    // Draw Y-axis labels (BPM)
    final labelStyle = GoogleFonts.jetBrainsMono(
      fontSize: 9,
      color: RowCraftTheme.subtleGrey,
    );
    for (var i = 0; i < 3; i++) {
      final frac = i / 2.0;
      final bpm = displayMin + frac * displayRange;
      final y = topPad + (1.0 - frac) * chartHeight;
      final tp = TextPainter(
        text: TextSpan(text: '${bpm.round()}', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    // Draw X-axis labels
    for (var i = 0; i < 3; i++) {
      final frac = i / 2.0;
      final sec = (maxTime * frac).round();
      final x = leftPad + frac * chartWidth;
      final label = _formatDuration(Duration(seconds: sec));
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, topPad + chartHeight + 4));
    }

    // Draw HR line with zone coloring — draw segments between consecutive points
    for (var i = 1; i < hrSamples.length; i++) {
      final prev = hrSamples[i - 1];
      final curr = hrSamples[i];

      final x1 =
          leftPad + (prev.timestamp.inSeconds / maxTime) * chartWidth;
      final y1 = topPad +
          (1.0 - (prev.heartRate! - displayMin) / displayRange) *
              chartHeight;
      final x2 =
          leftPad + (curr.timestamp.inSeconds / maxTime) * chartWidth;
      final y2 = topPad +
          (1.0 - (curr.heartRate! - displayMin) / displayRange) *
              chartHeight;

      final avgBpm = ((prev.heartRate! + curr.heartRate!) / 2).round();
      final color = _hrZoneColor(avgBpm, maxHr: maxHr);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_HrChartPainter old) => old.samples != samples;
}

// ---------------------------------------------------------------------------
// Splits Table
// ---------------------------------------------------------------------------

class _SplitsTable extends StatelessWidget {
  final List<SplitData> splits;
  final List<WorkoutSegment> segments;

  const _SplitsTable({required this.splits, required this.segments});

  @override
  Widget build(BuildContext context) {
    final headerStyle = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: RowCraftTheme.subtleGrey,
      letterSpacing: 0.5,
    );
    final cellStyle = GoogleFonts.jetBrainsMono(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: RowCraftTheme.metricWhite,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: RowCraftTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text('#', style: headerStyle)),
                  SizedBox(
                      width: 48,
                      child: Text('TYPE', style: headerStyle)),
                  Expanded(child: Text('DIST', style: headerStyle)),
                  Expanded(child: Text('TIME', style: headerStyle)),
                  Expanded(child: Text('PACE', style: headerStyle)),
                  SizedBox(
                      width: 36,
                      child: Text('S/M', style: headerStyle)),
                  SizedBox(
                      width: 32,
                      child: Text('HR', style: headerStyle)),
                ],
              ),
            ),
            const Divider(height: 1, color: RowCraftTheme.surfaceContainerHigh),
            // Data rows
            ...splits.asMap().entries.map((entry) {
              final i = entry.key;
              final split = entry.value;
              final segIndex = split.intervalIndex;
              final segType = segIndex < segments.length
                  ? segments[segIndex].type
                  : SegmentType.work;
              final color = _segmentColor(segType);

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    // # with color indicator
                    SizedBox(
                      width: 28,
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('${i + 1}', style: cellStyle),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        segType.name.substring(0, 1).toUpperCase() +
                            segType.name.substring(1, math.min(4, segType.name.length)),
                        style: cellStyle.copyWith(
                          color: color,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${split.distance.toInt()}m',
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formatDuration(split.time),
                        style: cellStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _formatPaceTenths(split.avgPace),
                        style: cellStyle,
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${split.avgStrokeRate}',
                        style: cellStyle,
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        split.avgHeartRate != null
                            ? '${split.avgHeartRate}'
                            : '--',
                        style: cellStyle,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save / Discard Bar
// ---------------------------------------------------------------------------

class _SaveDiscardBar extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const _SaveDiscardBar({required this.onSave, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: RowCraftTheme.surfaceContainerHigh),
        ),
      ),
      child: Row(
        children: [
          // Discard (text button)
          TextButton(
            onPressed: onDiscard,
            child: Text(
              'Discard',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: RowCraftTheme.errorRose,
              ),
            ),
          ),
          const Spacer(),
          // Save Workout (prominent green)
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save, size: 20),
              label: Text(
                'Save Workout',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: RowCraftTheme.successGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save Progress Overlay
// ---------------------------------------------------------------------------

class _SaveProgressOverlay extends ConsumerWidget {
  final SaveProgress saveProgress;
  final VoidCallback onRetry;

  const _SaveProgressOverlay({
    required this.saveProgress,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = saveProgress == SaveProgress.done;
    final isError = saveProgress == SaveProgress.error;
    final isSavedToCloud = saveProgress == SaveProgress.savedToCloud || isDone;

    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone)
                const Icon(Icons.check_circle, color: RowCraftTheme.successGreen, size: 64)
              else if (isError)
                const Icon(Icons.error_outline, color: RowCraftTheme.errorRose, size: 64)
              else
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: RowCraftTheme.primaryBlue,
                    strokeWidth: 3,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                isDone
                    ? 'SAVING SUCCESSFUL'
                    : isError
                        ? 'SAVE FAILED'
                        : 'SAVING YOUR SESSION',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 32),

              // Service status rows
              _ServiceStatusRow(
                icon: Icons.cloud_upload,
                label: 'RowCraft Cloud',
                isDone: isSavedToCloud,
                isActive: !isSavedToCloud && !isError,
              ),
              const SizedBox(height: 16),
              _C2LogbookStatusRow(
                isDone: isDone,
                isSyncing: false,
              ),

              if (isError) ...[
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RowCraftTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceStatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDone;
  final bool isActive;

  const _ServiceStatusRow({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: RowCraftTheme.subtleGrey),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: RowCraftTheme.metricWhite,
            ),
          ),
        ),
        if (isDone)
          const Icon(Icons.check_circle,
              size: 20, color: RowCraftTheme.successGreen)
        else if (isActive)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: RowCraftTheme.primaryBlue,
            ),
          )
        else
          const Icon(Icons.remove,
              size: 20, color: RowCraftTheme.subtleGrey),
      ],
    );
  }
}

class _C2LogbookStatusRow extends ConsumerWidget {
  final bool isDone;
  final bool isSyncing;

  const _C2LogbookStatusRow({
    required this.isDone,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: ref.read(c2LogbookServiceProvider).isLinked(),
      builder: (context, snapshot) {
        final isLinked = snapshot.data ?? false;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 20, color: RowCraftTheme.subtleGrey),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: Text(
                'Concept2 Logbook',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: RowCraftTheme.metricWhite,
                ),
              ),
            ),
            if (!isLinked)
              const Icon(Icons.remove, size: 20, color: RowCraftTheme.subtleGrey)
            else if (isDone)
              const Icon(Icons.check_circle,
                  size: 20, color: RowCraftTheme.successGreen)
            else if (isSyncing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RowCraftTheme.primaryBlue,
                ),
              )
            else
              const Icon(Icons.remove,
                  size: 20, color: RowCraftTheme.subtleGrey),
          ],
        );
      },
    );
  }
}
