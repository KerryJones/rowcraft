import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../models/achievement.dart';
import '../../models/personal_record.dart';
import '../../utils/pace_utils.dart' show formatPace;
import '../../utils/workout_utils.dart' show formatDistance, formatDistanceKm, formatDistanceShort;
import '../../widgets/content_constraint.dart';
import '../../models/workout_result.dart';
import '../../models/workout_segment.dart';
import '../../utils/segment_color.dart';
import '../../models/workout_time_sample.dart';
import '../../widgets/discard_workout_dialog.dart';
import '../../widgets/save_discard_buttons.dart';
import 'save_auto_nav_mixin.dart';
import 'workout_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _formatDistance(double distance) => '${distance.toInt()}m';

// ---------------------------------------------------------------------------
// WorkoutSummaryContent — shown inside WorkoutScreen when phase == finished
// ---------------------------------------------------------------------------

class WorkoutSummaryContent extends ConsumerStatefulWidget {
  const WorkoutSummaryContent({super.key});

  @override
  ConsumerState<WorkoutSummaryContent> createState() =>
      _WorkoutSummaryContentState();
}

class _WorkoutSummaryContentState extends ConsumerState<WorkoutSummaryContent>
    with SaveAutoNavMixin {
  @override
  void dispose() {
    cancelAutoNavTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    ref.listen(workoutSessionProvider, handleSaveProgressChange);

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
    final hasHrData =
        timeSamples != null &&
        timeSamples.any((s) => s.heartRate != null && s.heartRate! > 0);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 160),
          child: ContentConstraint(
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

                // Combined timeline chart (pace bars + HR line overlay)
                const _SectionHeader(title: 'TIMELINE'),
                if (timeSamples != null && timeSamples.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: 200,
                      child: CustomPaint(
                        size: const Size(double.infinity, 200),
                        painter: _CombinedChartPainter(
                          samples: timeSamples,
                          segments: segments,
                          maxHr: maxHr,
                          hasHrData: hasHrData,
                        ),
                      ),
                    ),
                  )
                else
                  const _NoDataPlaceholder(label: 'No data'),

                const SizedBox(height: 20),

                // HR zone distribution bar (time spent in each zone)
                if (hasHrData) ...[
                  const _SectionHeader(title: 'HR ZONE DISTRIBUTION'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: 48,
                      child: CustomPaint(
                        size: const Size(double.infinity, 48),
                        painter: _HrZoneDistributionPainter(
                          samples: timeSamples,
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
        ),

        // Save/discard buttons at the bottom
        if (!showSaveOverlay)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SaveDiscardBar(
              onSave: () {
                startSaveOverlay();
                ref.read(workoutSessionProvider.notifier).saveResult();
              },
              onDiscard: () => _showDiscardConfirmation(context),
            ),
          ),

        // Save progress overlay
        if (showSaveOverlay)
          Positioned.fill(
            child: SaveProgressOverlay(
              saveProgress: session.saveProgress,
              syncError: session.syncError,
              onRetry: () {
                ref.read(workoutSessionProvider.notifier).saveResult();
              },
            ),
          ),
      ],
    );
  }

  void _showDiscardConfirmation(BuildContext context) {
    showDiscardWorkoutDialog(context, ref);
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
                  value: '${formatPace(avgPace)}/500m',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCell(label: 'AVG S/M', value: '$avgSR'),
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
                child: _StatCell(label: 'CALORIES', value: '$calories'),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: RowCraftTheme.metricWhite,
              ),
              maxLines: 1,
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
// Combined Chart: pace bars (colored by segment zone) + HR line overlay
// ---------------------------------------------------------------------------

class _CombinedChartPainter extends CustomPainter {
  final List<WorkoutTimeSample> samples;
  final List<WorkoutSegment> segments;
  final int maxHr;
  final bool hasHrData;

  _CombinedChartPainter({
    required this.samples,
    required this.segments,
    required this.maxHr,
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
      final label = _formatDuration(Duration(seconds: sec));
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
  bool shouldRepaint(_CombinedChartPainter old) =>
      old.samples != samples ||
      old.hasHrData != hasHrData ||
      old.segments != segments ||
      old.maxHr != maxHr;
}

// ---------------------------------------------------------------------------
// HR Zone Distribution Bar (Zwift-style colored band)
// ---------------------------------------------------------------------------

class _HrZoneDistributionPainter extends CustomPainter {
  final List<WorkoutTimeSample> samples;
  final int maxHr;

  static const _zoneColors = [
    RowCraftTheme.hrZone1,
    RowCraftTheme.hrZone2,
    RowCraftTheme.hrZone3,
    RowCraftTheme.hrZone4,
    RowCraftTheme.hrZone5,
  ];

  _HrZoneDistributionPainter({required this.samples, required this.maxHr});

  @override
  void paint(Canvas canvas, Size size) {
    final hrSamples = samples
        .where((s) => s.heartRate != null && s.heartRate! > 0)
        .toList();
    if (hrSamples.isEmpty) return;

    // Count time in each zone (1-5)
    final zoneCounts = List.filled(5, 0);
    for (final s in hrSamples) {
      final pct = s.heartRate! / maxHr;
      final zone = pct < 0.6
          ? 0
          : pct < 0.7
          ? 1
          : pct < 0.8
          ? 2
          : pct < 0.9
          ? 3
          : 4;
      zoneCounts[zone]++;
    }
    final total = hrSamples.length.toDouble();

    // Draw colored zone bands
    const barHeight = 28.0;
    const barTop = 0.0;
    const radius = 8.0;

    // Find last zone with data for rounded corner detection
    var lastNonZeroZone = 4;
    for (var i = 4; i >= 0; i--) {
      if (zoneCounts[i] > 0) {
        lastNonZeroZone = i;
        break;
      }
    }

    var x = 0.0;
    for (var i = 0; i < 5; i++) {
      final width = (zoneCounts[i] / total) * size.width;
      if (width <= 0) continue;

      final isFirst = x == 0;
      final isLast = i == lastNonZeroZone;

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, barTop, width, barHeight),
        topLeft: isFirst ? const Radius.circular(radius) : Radius.zero,
        bottomLeft: isFirst ? const Radius.circular(radius) : Radius.zero,
        topRight: isLast ? const Radius.circular(radius) : Radius.zero,
        bottomRight: isLast ? const Radius.circular(radius) : Radius.zero,
      );
      canvas.drawRRect(rrect, Paint()..color = _zoneColors[i]);

      // Zone label inside the band (if wide enough)
      if (width > 30) {
        final label = 'Z${i + 1}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            x + (width - tp.width) / 2,
            barTop + (barHeight - tp.height) / 2,
          ),
        );
      }

      x += width;
    }

    // Zone legend below the bar
    final legendStyle = GoogleFonts.inter(
      fontSize: 9,
      color: RowCraftTheme.subtleGrey,
    );
    x = 0;
    for (var i = 0; i < 5; i++) {
      final width = (zoneCounts[i] / total) * size.width;
      if (width <= 0) continue;

      final pct = (zoneCounts[i] / total * 100).round();
      if (width > 24) {
        final tp = TextPainter(
          text: TextSpan(text: '$pct%', style: legendStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + (width - tp.width) / 2, barHeight + 4));
      }
      x += width;
    }
  }

  @override
  bool shouldRepaint(_HrZoneDistributionPainter old) =>
      old.samples != samples || old.maxHr != maxHr;
}

// ---------------------------------------------------------------------------
// Splits Table
// ---------------------------------------------------------------------------

class _SplitsTable extends StatelessWidget {
  final List<SplitData> splits;
  final List<WorkoutSegment> segments;

  const _SplitsTable({required this.splits, required this.segments});

  /// Detect auto-splits: multiple splits all sharing the same segment index,
  /// which means they are sub-splits of a single distance segment.
  bool get _isAutoSplit {
    if (splits.length <= 1) return false;
    final firstIdx = splits.first.intervalIndex;
    return splits.every((s) => s.intervalIndex == firstIdx);
  }

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

    final isAutoSplit = _isAutoSplit;

    // Precompute cumulative distances for auto-split labels
    final cumDistances = isAutoSplit
        ? () {
            final result = <double>[];
            var sum = 0.0;
            for (final s in splits) {
              sum += s.distance;
              result.add(sum);
            }
            return result;
          }()
        : <double>[];

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 28, child: Text('#', style: headerStyle)),
                  SizedBox(width: 48, child: Text(isAutoSplit ? 'SPLIT' : 'TYPE', style: headerStyle)),
                  Expanded(child: Text('DIST', style: headerStyle)),
                  Expanded(child: Text('TIME', style: headerStyle)),
                  Expanded(child: Text('PACE', style: headerStyle)),
                  SizedBox(width: 36, child: Text('S/M', style: headerStyle)),
                  SizedBox(width: 32, child: Text('HR', style: headerStyle)),
                ],
              ),
            ),
            const Divider(height: 1, color: RowCraftTheme.surfaceContainerHigh),
            // Data rows
            ...splits.asMap().entries.map((entry) {
              final i = entry.key;
              final split = entry.value;
              final segIndex = split.intervalIndex;
              final seg = segIndex < segments.length
                  ? segments[segIndex]
                  : null;
              final color = seg != null
                  ? segmentDisplayColor(seg)
                  : RowCraftTheme.segmentRest;

              String typeLabel;
              if (isAutoSplit) {
                typeLabel = formatDistance(cumDistances[i]);
              } else {
                if (seg == null) {
                  typeLabel = '--';
                } else if (seg.isRest) {
                  typeLabel = 'Rest';
                } else if (seg.targetHrZone != null) {
                  typeLabel = 'Z${seg.targetHrZone}';
                } else {
                  typeLabel = seg.durationType == DurationType.time
                      ? 'Free'
                      : 'Row';
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                        typeLabel,
                        style: cellStyle.copyWith(color: color, fontSize: 10),
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
                        '${formatPace(split.avgPace)}/500m',
                        style: cellStyle,
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text('${split.avgStrokeRate}', style: cellStyle),
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
      child: SaveDiscardButtons(onSave: onSave, onDiscard: onDiscard),
    );
  }
}

// ---------------------------------------------------------------------------
// Save Progress Overlay
// ---------------------------------------------------------------------------

class SaveProgressOverlay extends ConsumerWidget {
  final SaveProgress saveProgress;
  final String? syncError;
  final VoidCallback onRetry;

  const SaveProgressOverlay({
    super.key,
    required this.saveProgress,
    this.syncError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = saveProgress == SaveProgress.done;
    final isError = saveProgress == SaveProgress.error;
    final isSavedLocally =
        saveProgress == SaveProgress.savedLocally ||
        saveProgress == SaveProgress.savedToCloud ||
        isDone;
    final isSavedToCloud = saveProgress == SaveProgress.savedToCloud || isDone;

    final session = ref.watch(workoutSessionProvider);
    final newPRs = session.newPRs;
    final newAchievements = session.newAchievements;

    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDone && syncError != null)
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: RowCraftTheme.warningAmber,
                    size: 64,
                  )
                else if (isDone)
                  const Icon(
                    Icons.check_circle,
                    color: RowCraftTheme.successGreen,
                    size: 64,
                  )
                else if (isError)
                  const Icon(
                    Icons.error_outline,
                    color: RowCraftTheme.errorRose,
                    size: 64,
                  )
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
                  isDone && syncError != null
                      ? 'SAVED LOCALLY'
                      : isDone
                      ? 'WORKOUT SAVED'
                      : isError
                      ? 'SAVE FAILED'
                      : 'SAVING',
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
                  icon: isSavedLocally && !isSavedToCloud
                      ? Icons.cloud_off
                      : Icons.cloud_done,
                  label: 'RowCraft',
                  isDone: isSavedToCloud || isDone,
                  isActive: !isSavedLocally && !isError,
                  subtitle: isSavedLocally && !isSavedToCloud
                      ? 'Saved offline — will sync later'
                      : null,
                ),
                const SizedBox(height: 16),
                _C2LogbookStatusRow(
                  c2Status: session.c2SyncStatus,
                ),

                // New PRs
                if (isDone && newPRs.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ...newPRs.map((pr) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PrChip(pr: pr),
                  )),
                ],

                // New achievements
                if (isDone && newAchievements.isNotEmpty) ...[
                  SizedBox(height: newPRs.isNotEmpty ? 8 : 24),
                  ...newAchievements.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AchievementChip(achievement: a),
                  )),
                ],

                // Show sync error details if present
                if (syncError != null && (isDone || isError)) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: RowCraftTheme.warningAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            syncError!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: RowCraftTheme.warningAmber,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: syncError!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.copy,
                            size: 16,
                            color: RowCraftTheme.warningAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                if (isError)
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

                if (isDone || isError)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(
                        'Return Home',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: RowCraftTheme.subtleGrey,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
  final String? subtitle;

  const _ServiceStatusRow({
    required this.icon,
    required this.label,
    required this.isDone,
    required this.isActive,
    this.subtitle,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: RowCraftTheme.metricWhite,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: RowCraftTheme.subtleGrey,
                  ),
                ),
            ],
          ),
        ),
        if (isDone)
          const Icon(
            Icons.check_circle,
            size: 20,
            color: RowCraftTheme.successGreen,
          )
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
          const Icon(Icons.remove, size: 20, color: RowCraftTheme.subtleGrey),
      ],
    );
  }
}

class _PrChip extends StatelessWidget {
  final PersonalRecord pr;

  const _PrChip({required this.pr});

  String _formatValue() {
    return switch (pr.prType) {
      PrType.highestFtp => '${pr.value}W',
      PrType.longestDistance => formatDistanceKm(pr.value),
      _ => '${formatPace(pr.value)}/500m',
    };
  }

  String? _formatDelta() {
    final prev = pr.previousValue;
    if (prev == null) return null;
    if (pr.prType.lowerIsBetter) {
      final diff = prev - pr.value;
      if (diff <= 0) return null;
      final seconds = diff ~/ 10;
      final tenths = diff % 10;
      return '-$seconds.${tenths}s';
    } else {
      final diff = pr.value - prev;
      if (diff <= 0) return null;
      if (pr.prType == PrType.longestDistance) {
        return '+${formatDistanceKm(diff)}';
      }
      return '+${diff}W';
    }
  }

  @override
  Widget build(BuildContext context) {
    final delta = _formatDelta();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: RowCraftTheme.warningAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RowCraftTheme.warningAmber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, size: 20, color: RowCraftTheme.warningAmber),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'New PR!',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: RowCraftTheme.warningAmber,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                pr.prType.label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatValue(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (delta != null)
                Text(
                  delta,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: RowCraftTheme.successGreen,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  final Achievement achievement;

  const _AchievementChip({required this.achievement});

  String get _label {
    final type = achievement.achievementType;
    final t = achievement.threshold;
    return switch (type) {
      AchievementType.totalDistance => '${type.label}: ${formatDistanceShort(t)}',
      AchievementType.workoutCount => '${type.label}: $t',
      AchievementType.planCompleted => '${type.label}: $t',
      AchievementType.streakDays => '${type.label}: ${t}d',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: RowCraftTheme.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RowCraftTheme.primaryBlue.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, size: 20, color: RowCraftTheme.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Achievement Unlocked!',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RowCraftTheme.primaryBlue,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _C2LogbookStatusRow extends StatelessWidget {
  final C2SyncStatus c2Status;

  const _C2LogbookStatusRow({required this.c2Status});

  @override
  Widget build(BuildContext context) {
    final (Widget trailing, String sublabel) = switch (c2Status) {
      C2SyncStatus.idle => (
        const Icon(Icons.remove, size: 20, color: RowCraftTheme.subtleGrey),
        '',
      ),
      C2SyncStatus.notLinked => (
        const Icon(Icons.remove, size: 20, color: RowCraftTheme.subtleGrey),
        'Not linked',
      ),
      C2SyncStatus.synced => (
        const Icon(
          Icons.check_circle,
          size: 20,
          color: RowCraftTheme.successGreen,
        ),
        '',
      ),
      C2SyncStatus.failed => (
        const Icon(
          Icons.warning_amber_rounded,
          size: 20,
          color: RowCraftTheme.warningAmber,
        ),
        'Will retry',
      ),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.menu_book, size: 20, color: RowCraftTheme.subtleGrey),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Concept2 Logbook',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: RowCraftTheme.metricWhite,
                ),
              ),
              if (sublabel.isNotEmpty)
                Text(
                  sublabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: RowCraftTheme.subtleGrey,
                  ),
                ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
