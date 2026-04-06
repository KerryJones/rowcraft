import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../models/workout_segment.dart';
import '../../utils/pace_utils.dart';
import '../../utils/segment_color.dart';
import '../ble/ble_provider.dart';
import '../ble/pm5_service.dart';
import 'ftp_result_dialog.dart';
import 'rowing_animation.dart';
import 'workout_engine.dart';
import 'workout_provider.dart';
import 'workout_summary_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------


/// Effective duration in seconds (for proportional width in profile graph).
/// Approximates web's getEffectiveDuration(). Resolves intensity to pace
/// using FTP, then computes time from distance and pace.
double _getEffectiveDuration(WorkoutSegment seg, int ftpWatts) {
  switch (seg.durationType) {
    case DurationType.time:
      return seg.durationValue;
    case DurationType.distance:
      final double? midPace;
      if (seg.targetIntensity != null) {
        final resolved = resolveIntensityToPace(
          seg.targetIntensity!.min,
          seg.targetIntensity!.max,
          ftpWatts,
        );
        midPace = resolved.paceMid.toDouble();
      } else {
        midPace = null;
      }
      final pacePerMeter = midPace != null ? (midPace / 10) / 500 : 0.24;
      return seg.durationValue * pacePerMeter;
    case DurationType.calories:
      return (seg.durationValue / 15) * 60;
  }
}

/// Format pace tenths to M:SS
String _formatPace(double tenths) {
  final total = tenths.toInt();
  if (total == 0) return '--:--';
  final m = total ~/ 600;
  final r = total % 600;
  return '$m:${(r ~/ 10).toString().padLeft(2, '0')}';
}

/// HR zone info: name, label, color.
({String name, String label, Color color}) _hrZoneInfo(int zone) {
  return switch (zone) {
    1 => (name: 'ZONE 1', label: 'RECOVERY', color: RowCraftTheme.hrZone1),
    2 => (name: 'ZONE 2', label: 'ENDURANCE', color: RowCraftTheme.hrZone2),
    3 => (name: 'ZONE 3', label: 'TEMPO', color: RowCraftTheme.hrZone3),
    4 => (name: 'ZONE 4', label: 'THRESHOLD', color: RowCraftTheme.hrZone4),
    5 => (name: 'ZONE 5', label: 'VO2 MAX', color: RowCraftTheme.hrZone5),
    _ => (name: 'ZONE ?', label: '', color: RowCraftTheme.subtleGrey),
  };
}

/// HR zone estimate from BPM using percentage of max heart rate.
int _estimateHrZone(int bpm, {int maxHr = 190}) {
  if (bpm < (maxHr * 0.6).round()) return 1;
  if (bpm < (maxHr * 0.7).round()) return 2;
  if (bpm < (maxHr * 0.8).round()) return 3;
  if (bpm < (maxHr * 0.9).round()) return 4;
  return 5;
}

// ---------------------------------------------------------------------------
// WorkoutScreen
// ---------------------------------------------------------------------------

class WorkoutScreen extends ConsumerStatefulWidget {
  final String workoutId;
  final String? planId;
  final int? planWeek;
  final int? planSession;

  const WorkoutScreen({
    super.key,
    required this.workoutId,
    this.planId,
    this.planWeek,
    this.planSession,
  });

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  bool _ftpDialogShown = false;
  bool _isLocked = false;

  void _confirmStop(BuildContext ctx, VoidCallback onConfirmed) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: RowCraftTheme.surfaceContainer,
        title: Text(
          'End Workout?',
          style: GoogleFonts.inter(
            color: RowCraftTheme.metricWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Your progress so far will be saved.',
          style: GoogleFonts.inter(color: RowCraftTheme.subtleGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Keep Going',
              style: GoogleFonts.inter(color: RowCraftTheme.subtleGrey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              onConfirmed();
            },
            child: Text(
              'End Workout',
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workoutSessionProvider.notifier).loadWorkout(
        widget.workoutId,
        planId: widget.planId,
        planWeek: widget.planWeek,
        planSession: widget.planSession,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final engineState = session.engineState;

    // Reset dialog guard when flag is cleared
    if (!session.showFtpDialog) {
      _ftpDialogShown = false;
    }

    // Show FTP dialog once when workout completes with FTP data
    if (session.showFtpDialog &&
        session.calculatedFtp != null &&
        !_ftpDialogShown) {
      _ftpDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => FtpResultDialog(
            calculatedFtp: session.calculatedFtp!,
            calculationBasis: session.ftpCalculationBasis ?? '',
            onSave: (watts) {
              ref.read(workoutSessionProvider.notifier).saveFtp(watts);
              Navigator.of(context).pop();
            },
            onSkip: () {
              ref.read(workoutSessionProvider.notifier).dismissFtpDialog();
              Navigator.of(context).pop();
            },
          ),
        );
      });
    }

    final isActive = engineState.phase == WorkoutPhase.rowing ||
        engineState.phase == WorkoutPhase.resting ||
        engineState.phase == WorkoutPhase.paused;

    return Scaffold(
      backgroundColor: RowCraftTheme.surfaceDark,
      appBar: AppBar(
        toolbarHeight: 40,
        title: Text(
          session.workoutTitle,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (engineState.phase != WorkoutPhase.idle)
            _PhaseIndicator(phase: engineState.phase),
          if (isActive)
            IconButton(
              icon: Icon(
                _isLocked ? Icons.lock : Icons.lock_open,
                size: 20,
                color: _isLocked
                    ? RowCraftTheme.warningAmber
                    : RowCraftTheme.subtleGrey,
              ),
              onPressed: () => setState(() => _isLocked = !_isLocked),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40),
            ),
        ],
      ),
      body: SafeArea(
        child: engineState.phase == WorkoutPhase.finished &&
                session.pendingResult != null
            ? const WorkoutSummaryContent()
            : Stack(
          children: [
            // Main layout
            Column(
              children: [
                // BLE status
                const _BleStatusBar(),

                // Overall stats (time, distance, calories)
                _OverallStatsBar(session: session),

                // Workout profile graph
                if (session.expandedSegments.isNotEmpty)
                  _WorkoutProfileGraph(session: session),

                // Hero section (pace, guide bar, stroke rate)
                Expanded(child: _HeroSection(session: session)),

                // Current segment (merged target + progress)
                _CurrentSegment(session: session),

                // Up-next preview
                _UpNextPreview(session: session),

                // Controls (wrapped in IgnorePointer when locked)
                IgnorePointer(
                  ignoring: _isLocked,
                  child: Opacity(
                    opacity: _isLocked ? 0.4 : 1.0,
                    child: _WorkoutControls(
                      phase: engineState.phase,
                      onStart: () =>
                          ref.read(workoutSessionProvider.notifier).start(),
                      onPause: () =>
                          ref.read(workoutSessionProvider.notifier).pause(),
                      onResume: () =>
                          ref.read(workoutSessionProvider.notifier).resume(),
                      onStop: () => _confirmStop(
                        context,
                        () => ref.read(workoutSessionProvider.notifier).stop(),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Manual pause overlay — full-screen with Keep Rowing / Stop Rowing
            if (engineState.phase == WorkoutPhase.paused &&
                !engineState.isAutoPaused)
              Positioned.fill(
                child: _ManualPauseOverlay(
                  onResume: () =>
                      ref.read(workoutSessionProvider.notifier).resume(),
                  onStop: () =>
                      ref.read(workoutSessionProvider.notifier).stop(),
                ),
              ),

            // Overlay banners (don't push layout)
            if (engineState.phase == WorkoutPhase.paused &&
                engineState.isAutoPaused)
              const Positioned(
                top: 36,
                left: 0,
                right: 0,
                child: _AutoPauseBanner(),
              ),
            if (!engineState.isAutoPaused &&
                engineState.secondsOutOfRange > 0 &&
                engineState.phase == WorkoutPhase.rowing)
              Positioned(
                top: 36,
                left: 0,
                right: 0,
                child: _PaceFailWarning(
                  secondsOut: engineState.secondsOutOfRange,
                  threshold: engineState.paceFailThreshold,
                ),
              ),

            // Lock overlay indicator
            if (_isLocked)
              Positioned(
                bottom: 90,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14,
                            color: RowCraftTheme.warningAmber),
                        SizedBox(width: 4),
                        Text('Screen locked',
                            style: TextStyle(
                                color: RowCraftTheme.warningAmber,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BLE Status Bar (28px) — PM5 connection only
// ---------------------------------------------------------------------------

class _BleStatusBar extends ConsumerWidget {
  const _BleStatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final pm5Connected =
        bleState.pm5ConnectionState == PM5ConnectionState.connected;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: RowCraftTheme.surfaceContainer,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pm5Connected
                  ? RowCraftTheme.successGreen
                  : RowCraftTheme.subtleGrey,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            pm5Connected ? 'Rower' : 'Rower --',
            style: TextStyle(
              fontSize: 11,
              color: pm5Connected
                  ? RowCraftTheme.metricWhite
                  : RowCraftTheme.subtleGrey,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overall Stats Bar — TIME | DIST | CAL
// ---------------------------------------------------------------------------

class _OverallStatsBar extends StatelessWidget {
  final WorkoutSessionState session;

  const _OverallStatsBar({required this.session});

  @override
  Widget build(BuildContext context) {
    final data = session.pm5Data;

    return Container(
      height: 36,
      color: RowCraftTheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _stat(context, 'TIME', data.elapsedFormatted),
          _stat(context, 'DIST', data.distanceFormatted),
          _stat(context, 'CAL', '${data.calories}'),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: RowCraftTheme.subtleGrey,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: RowCraftTheme.metricWhite,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Workout Profile Graph (64px) — CustomPaint
// ---------------------------------------------------------------------------

class _WorkoutProfileGraph extends StatelessWidget {
  final WorkoutSessionState session;

  const _WorkoutProfileGraph({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: CustomPaint(
        size: const Size(double.infinity, 64),
        painter: _WorkoutProfilePainter(
          segments: session.expandedSegments,
          currentIndex: session.engineState.currentSegmentIndex,
          segmentProgress: session.engineState.segmentProgress,
          phase: session.engineState.phase,
          ftpWatts: session.ftpWatts,
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

  _WorkoutProfilePainter({
    required this.segments,
    required this.currentIndex,
    required this.segmentProgress,
    required this.phase,
    required this.ftpWatts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    const barGap = 1.5;
    const minHeightFraction = 0.15;
    const defaultPaceMin = 1000.0;
    const defaultPaceMax = 1800.0;

    final durations = segments.map((s) => _getEffectiveDuration(s, ftpWatts)).toList();
    final totalDuration = durations.fold<double>(0, (a, b) => a + b);
    if (totalDuration <= 0) return;

    // Compute pace range for height mapping
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
    double paceMin, paceMax;
    if (paces.isEmpty) {
      paceMin = defaultPaceMin;
      paceMax = defaultPaceMax;
    } else {
      final minP = paces.reduce(math.min);
      final maxP = paces.reduce(math.max);
      final range = maxP - minP;
      final pad = range == 0 ? 200.0 : range * 0.1;
      paceMin = math.max(0, minP - pad);
      paceMax = maxP + pad;
    }

    double paceToHeight(double? pace) {
      if (pace == null) return minHeightFraction;
      final range = paceMax - paceMin;
      if (range == 0) return 0.7;
      final normalized = 1 - (pace - paceMin) / range;
      return minHeightFraction + normalized * (1 - minHeightFraction);
    }

    final totalGapWidth = barGap * (segments.length - 1);
    final availableWidth = size.width - totalGapWidth;

    // Draw bars
    var x = 0.0;
    double playheadX = 0;

    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final widthFraction = durations[i] / totalDuration;
      final barWidth = math.max(2.0, widthFraction * availableWidth);
      final double? avgPace;
      if (seg.targetIntensity != null) {
        final resolved = resolveIntensityToPace(
          seg.targetIntensity!.min,
          seg.targetIntensity!.max,
          ftpWatts,
        );
        avgPace = resolved.paceMid.toDouble();
      } else {
        avgPace = null;
      }
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

    // Draw playhead line
    if (phase != WorkoutPhase.idle && phase != WorkoutPhase.finished) {
      final playheadPaint = Paint()
        ..color = RowCraftTheme.metricWhite
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        playheadPaint,
      );

      // Small triangle at top of playhead
      final trianglePath = Path()
        ..moveTo(playheadX - 4, 0)
        ..lineTo(playheadX + 4, 0)
        ..lineTo(playheadX, 5)
        ..close();
      canvas.drawPath(
        trianglePath,
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
        old.ftpWatts != ftpWatts;
  }
}

// ---------------------------------------------------------------------------
// Current Segment — merged target + progress + HR
// ---------------------------------------------------------------------------

/// Remaining label for segment countdown.
String _remainingLabel(WorkoutEngineState state) {
  final segment = state.currentSegment;
  if (segment == null) return '';

  switch (segment.durationType) {
    case DurationType.time:
      final totalSec = segment.durationValue.toInt();
      final remaining =
          (totalSec * (1 - state.segmentProgress)).round().clamp(0, totalSec);
      final min = remaining ~/ 60;
      final sec = remaining % 60;
      return '$min:${sec.toString().padLeft(2, '0')}';
    case DurationType.distance:
      final totalM = segment.durationValue;
      final remaining =
          (totalM - state.segmentElapsedDistance).clamp(0.0, totalM).toInt();
      return '${remaining}m';
    case DurationType.calories:
      final totalCal = segment.durationValue;
      final remaining = (totalCal - state.segmentElapsedCalories)
          .clamp(0.0, totalCal)
          .round();
      return '${remaining}cal';
  }
}

class _CurrentSegment extends StatelessWidget {
  final WorkoutSessionState session;

  const _CurrentSegment({required this.session});

  @override
  Widget build(BuildContext context) {
    final engineState = session.engineState;
    final segment = engineState.currentSegment ??
        session.expandedSegments.firstOrNull;
    if (segment == null) return const SizedBox.shrink();

    final isActive = engineState.phase == WorkoutPhase.rowing ||
        engineState.phase == WorkoutPhase.resting ||
        engineState.phase == WorkoutPhase.paused;
    final segColor = engineState.phase == WorkoutPhase.paused
        ? RowCraftTheme.warningAmber
        : segmentDisplayColor(segment);
    final segments = session.expandedSegments;
    final currentIndex = isActive ? engineState.currentSegmentIndex : 0;

    final hasPaceTarget = segment.targetIntensity != null;
    final hasSpmTarget = segment.targetStrokeRate != null;
    final data = session.pm5Data;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: segColor.withValues(alpha: 0.08),
        border: const Border(
          top: BorderSide(color: RowCraftTheme.surfaceContainerHigh, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Row 1: segment label + progress bar + remaining + counter
          Row(
            children: [
              Text(
                '${segment.type.name.toUpperCase()} ${segment.durationLabel}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: segColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
              if (isActive)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: engineState.segmentProgress,
                      minHeight: 6,
                      backgroundColor: RowCraftTheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(segColor),
                    ),
                  ),
                ),
              if (!isActive) const Spacer(),
              const SizedBox(width: 8),
              if (isActive)
                Text(
                  _remainingLabel(engineState),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: RowCraftTheme.subtleGrey,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '${(currentIndex + 1).clamp(1, segments.length)}/${segments.length}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: RowCraftTheme.subtleGrey,
                ),
              ),
            ],
          ),

          // Row 2: target pace + target s/m + HR (only if targets or HR exist)
          if (hasPaceTarget || hasSpmTarget || data.heartRate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (hasPaceTarget) ...[
                  Text(
                    _formatPace(resolveIntensityToPace(
                      segment.targetIntensity!.min,
                      segment.targetIntensity!.max,
                      session.ftpWatts,
                    ).paceMid.toDouble()),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: RowCraftTheme.successGreen,
                    ),
                  ),
                  Text(
                    ' /500m',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: RowCraftTheme.subtleGrey,
                    ),
                  ),
                ],
                if (hasPaceTarget && hasSpmTarget)
                  const SizedBox(width: 16),
                if (hasSpmTarget)
                  Text(
                    '${segment.targetStrokeRate!.midpoint} s/m',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: RowCraftTheme.successGreen,
                    ),
                  ),
                const Spacer(),
                // HR indicator
                if (data.heartRate != null && data.heartRate! > 0)
                  Builder(builder: (_) {
                    final hr = data.heartRate!;
                    final zone = segment.targetHrZone ??
                        _estimateHrZone(hr,
                            maxHr: session.maxHeartRate ?? 190);
                    final info = _hrZoneInfo(zone);
                    final isEstimated = segment.targetHrZone == null;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, size: 14,
                            color: info.color),
                        const SizedBox(width: 4),
                        Text(
                          '$hr',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: RowCraftTheme.metricWhite,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: info.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${isEstimated ? '~' : ''}Z$zone',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: info.color,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Section — pace, guide bar, stroke rate
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  final WorkoutSessionState session;

  const _HeroSection({required this.session});

  @override
  Widget build(BuildContext context) {
    final data = session.pm5Data;
    final segment = session.engineState.currentSegment;
    final isActive = session.engineState.phase == WorkoutPhase.rowing ||
        session.engineState.phase == WorkoutPhase.resting;

    // Pace color based on target
    Color splitColor = RowCraftTheme.metricWhite;
    if (segment?.targetIntensity != null && data.pace > 0) {
      final resolved = resolveIntensityToPace(
        segment!.targetIntensity!.min,
        segment.targetIntensity!.max,
        session.ftpWatts,
      );
      final pace = data.pace.toDouble();
      if (pace >= resolved.paceMin && pace <= resolved.paceMax) {
        splitColor = RowCraftTheme.successGreen;
      } else if (pace > resolved.paceMax) {
        splitColor = RowCraftTheme.warningAmber;
      } else {
        splitColor = RowCraftTheme.accentTeal;
      }
    }

    // Stroke rate color + chevron direction
    final hasStrokeTarget = segment?.targetStrokeRate != null;
    Color srColor = RowCraftTheme.metricWhite;
    String? srChevron; // null = in range, '▲' = speed up, '▼' = slow down
    if (hasStrokeTarget && data.strokeRate > 0) {
      final sr = data.strokeRate;
      if (sr >= segment!.targetStrokeRate!.min &&
          sr <= segment.targetStrokeRate!.max) {
        srColor = RowCraftTheme.successGreen;
      } else if (sr < segment.targetStrokeRate!.min) {
        srColor = RowCraftTheme.warningAmber;
        srChevron = '\u25B2'; // ▲ speed up
      } else {
        srColor = RowCraftTheme.errorRose;
        srChevron = '\u25BC'; // ▼ slow down
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale down on small screens to prevent overflow
        final isCompact = constraints.maxHeight < 200;
        final paceFontSize = isCompact ? 60.0 : 80.0;
        final srFontSize = isCompact ? 36.0 : 44.0;
        final animHeight = isCompact ? 50.0 : 70.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hero pace
              Text(
                data.paceFormatted,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: paceFontSize,
                  fontWeight: FontWeight.w700,
                  color: splitColor,
                  letterSpacing: -2,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '/500m',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: RowCraftTheme.subtleGrey,
                    ),
              ),

              // Pace guide bar
              if (segment?.targetIntensity != null) ...[
                const SizedBox(height: 10),
                Builder(builder: (_) {
                  final resolved = resolveIntensityToPace(
                    segment!.targetIntensity!.min,
                    segment.targetIntensity!.max,
                    session.ftpWatts,
                  );
                  return _PaceGuideBar(
                    targetMin: resolved.paceMin.toDouble(),
                    targetMax: resolved.paceMax.toDouble(),
                    currentPace: data.pace.toDouble(),
                  );
                }),
              ],

              const SizedBox(height: 8),

              // Rowing animation — paces to target stroke rate (guide),
              // falls back to current rate when no target is set
              RowingAnimation(
                strokeRate:
                    segment?.targetStrokeRate?.midpoint ?? data.strokeRate,
                isActive: isActive,
                height: animHeight,
              ),

              const SizedBox(height: 8),

              // Stroke rate
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (srChevron != null)
                    Text(
                      srChevron,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: srFontSize * 0.5,
                        color: srColor,
                        height: 1.0,
                      ),
                    ),
                  if (srChevron != null) const SizedBox(width: 4),
                  Text(
                    '${data.strokeRate}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: srFontSize,
                      fontWeight: FontWeight.w600,
                      color: srColor,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    's/m',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                          color: RowCraftTheme.subtleGrey,
                        ),
                  ),
                ],
              ),
              // Target s/m now shown in _CurrentSegment below
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pace Guide Bar (40px)
// ---------------------------------------------------------------------------

class _PaceGuideBar extends StatelessWidget {
  final double targetMin;
  final double targetMax;
  final double currentPace;

  const _PaceGuideBar({
    required this.targetMin,
    required this.targetMax,
    required this.currentPace,
  });

  @override
  Widget build(BuildContext context) {
    final range = targetMax - targetMin;
    if (range <= 0) return const SizedBox.shrink();

    final displayMin = targetMin - range * 1.5;
    final displayMax = targetMax + range * 1.5;
    final displayRange = displayMax - displayMin;

    // Invert: slow (high pace) on left, fast (low pace) on right
    final pacePosition = currentPace > 0
        ? (1.0 - ((currentPace - displayMin) / displayRange).clamp(0.0, 1.0))
        : 0.5;

    final isInRange = currentPace >= targetMin && currentPace <= targetMax;
    final isTooSlow = currentPace > targetMax;

    final indicatorColor = isInRange
        ? RowCraftTheme.successGreen
        : isTooSlow
            ? RowCraftTheme.errorRose
            : RowCraftTheme.accentTeal;

    final barBgColor = isInRange
        ? RowCraftTheme.successGreen.withValues(alpha: 0.08)
        : isTooSlow
            ? RowCraftTheme.errorRose.withValues(alpha: 0.08)
            : RowCraftTheme.surfaceContainerHigh;

    // Invert zone positions: slow (high pace) on left, fast (low pace) on right
    final zoneLeft =
        (1.0 - ((targetMax - displayMin) / displayRange).clamp(0.0, 1.0));
    final zoneRight =
        (1.0 - ((targetMin - displayMin) / displayRange).clamp(0.0, 1.0));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Warning label area — fixed height to prevent layout jank
          SizedBox(
            height: 18,
            child: (currentPace > 0 && !isInRange)
                ? Align(
                    alignment: isTooSlow
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Text(
                      isTooSlow ? 'TOO SLOW' : 'TOO FAST',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isTooSlow
                            ? RowCraftTheme.warningAmber
                            : RowCraftTheme.accentTeal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                : null,
          ),
          // The bar (40px)
          SizedBox(
            height: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: width,
                      height: 40,
                      decoration: BoxDecoration(
                        color: barBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: RowCraftTheme.surfaceContainerHigh,
                          width: 1,
                        ),
                      ),
                    ),
                    // Green target zone
                    Positioned(
                      left: zoneLeft * width,
                      width: (zoneRight - zoneLeft) * width,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: RowCraftTheme.successGreen
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: RowCraftTheme.successGreen
                                .withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Current pace indicator
                    if (currentPace > 0)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 150),
                        left: (pacePosition * width - 4)
                            .clamp(0.0, (width - 8).clamp(0.0, double.infinity)),
                        top: 4,
                        bottom: 4,
                        child: Container(
                          width: 8,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: indicatorColor.withValues(alpha: 0.6),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stroke Rate Guide Bar (40px)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Up-Next Preview (36px) — EXR-style format
// ---------------------------------------------------------------------------

class _UpNextPreview extends StatelessWidget {
  final WorkoutSessionState session;

  const _UpNextPreview({required this.session});

  @override
  Widget build(BuildContext context) {
    final segments = session.expandedSegments;
    final isActive = session.engineState.phase == WorkoutPhase.rowing ||
        session.engineState.phase == WorkoutPhase.resting ||
        session.engineState.phase == WorkoutPhase.paused;
    final currentIndex = isActive ? session.engineState.currentSegmentIndex : 0;
    final nextIndex = currentIndex + 1;

    // Last segment — show "FINAL SEGMENT" (only when active)
    if (nextIndex >= segments.length) {
      if (!isActive) return const SizedBox.shrink();
      return Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: RowCraftTheme.subtleGrey, width: 3),
          ),
          color: Color(0x0DFFFFFF),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'FINAL SEGMENT',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: RowCraftTheme.subtleGrey,
            ),
          ),
        ),
      );
    }

    final next = segments[nextIndex];
    final nextColor = segmentDisplayColor(next);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: nextColor.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(color: nextColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Text(
            'UP NEXT',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: RowCraftTheme.subtleGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          if (next.targetIntensity != null)
            Text(
              '${_formatPace(resolveIntensityToPace(next.targetIntensity!.min, next.targetIntensity!.max, session.ftpWatts).paceMid.toDouble())} /500',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: nextColor,
              ),
            ),
          if (next.targetStrokeRate != null) ...[
            if (next.targetIntensity != null)
              const SizedBox(width: 8),
            Text(
              '${next.targetStrokeRate!.midpoint} s/m',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: nextColor,
              ),
            ),
          ],
          // Fallback: show segment type when no targets exist
          if (next.targetIntensity == null && next.targetStrokeRate == null)
            Text(
              next.type.name.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: nextColor,
              ),
            ),
          const Spacer(),
          Text(
            next.durationLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: nextColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Workout Controls (80px)
// ---------------------------------------------------------------------------

class _WorkoutControls extends ConsumerWidget {
  final WorkoutPhase phase;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _WorkoutControls({
    required this.phase,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm5Connected = ref.watch(bleProvider).pm5ConnectionState ==
        PM5ConnectionState.connected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status hint
          if (phase == WorkoutPhase.idle || phase == WorkoutPhase.ready)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                pm5Connected
                    ? 'Start rowing to begin'
                    : 'Connect rower to start',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: pm5Connected
                          ? RowCraftTheme.warningAmber
                          : RowCraftTheme.subtleGrey,
                    ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: switch (phase) {
              WorkoutPhase.idle || WorkoutPhase.ready => [
                  _ControlButton(
                    icon: Icons.play_arrow,
                    label: 'START',
                    color: pm5Connected
                        ? RowCraftTheme.successGreen
                        : RowCraftTheme.subtleGrey,
                    onPressed: pm5Connected ? onStart : null,
                    isLarge: true,
                  ),
                ],
              WorkoutPhase.countingDown => [
                  const _ControlButton(
                    icon: Icons.hourglass_top,
                    label: 'STARTING...',
                    color: RowCraftTheme.warningAmber,
                    onPressed: null,
                    isLarge: true,
                  ),
                ],
              WorkoutPhase.paused => [
                  _ControlButton(
                    icon: Icons.stop,
                    label: 'STOP',
                    color: RowCraftTheme.errorRose,
                    onPressed: onStop,
                    isLarge: false,
                  ),
                  const SizedBox(width: 32),
                  _ControlButton(
                    icon: Icons.play_arrow,
                    label: 'RESUME',
                    color: RowCraftTheme.successGreen,
                    onPressed: onResume,
                    isLarge: true,
                  ),
                ],
              WorkoutPhase.rowing || WorkoutPhase.resting => [
                  _ControlButton(
                    icon: Icons.pause,
                    label: 'PAUSE',
                    color: RowCraftTheme.warningAmber,
                    onPressed: onPause,
                    isLarge: true,
                  ),
                ],
              WorkoutPhase.finished => [
                  _ControlButton(
                    icon: Icons.check,
                    label: 'SAVE',
                    color: RowCraftTheme.successGreen,
                    onPressed: () => context.go('/'),
                    isLarge: true,
                  ),
                ],
            },
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLarge;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.isLarge,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLarge ? 64.0 : 48.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Icon(icon, size: isLarge ? 32 : 24),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Manual Pause Overlay — full-screen dark overlay
// ---------------------------------------------------------------------------

class _ManualPauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _ManualPauseOverlay({
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PAUSED',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 48),
                // Keep Rowing button (primary CTA)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.rowing, size: 24),
                    label: Text(
                      'Keep Rowing',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RowCraftTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // End Workout button (secondary)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmStop(context),
                    icon: const Icon(Icons.stop, size: 24),
                    label: Text(
                      'End Workout',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: RowCraftTheme.errorRose,
                      side: const BorderSide(
                        color: RowCraftTheme.errorRose,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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

  void _confirmStop(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RowCraftTheme.surfaceContainer,
        title: Text(
          'End Workout?',
          style: GoogleFonts.inter(
            color: RowCraftTheme.metricWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Your progress so far will be saved.',
          style: GoogleFonts.inter(color: RowCraftTheme.subtleGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Keep Going',
              style: GoogleFonts.inter(color: RowCraftTheme.subtleGrey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onStop();
            },
            child: Text(
              'End Workout',
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
// Pace Fail Warning (overlay)
// ---------------------------------------------------------------------------

class _PaceFailWarning extends StatelessWidget {
  final int secondsOut;
  final int threshold;

  const _PaceFailWarning({
    required this.secondsOut,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (threshold - secondsOut).clamp(0, threshold);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: RowCraftTheme.errorRose.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pace too slow — stopping in ${remaining}s',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
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
// Auto-Pause Banner (overlay)
// ---------------------------------------------------------------------------

class _AutoPauseBanner extends StatelessWidget {
  const _AutoPauseBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: RowCraftTheme.warningAmber.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline,
              color: Colors.black87, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Paused — start rowing to resume',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
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
// Phase Indicator badge
// ---------------------------------------------------------------------------

class _PhaseIndicator extends StatelessWidget {
  final WorkoutPhase phase;

  const _PhaseIndicator({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      WorkoutPhase.idle => ('IDLE', RowCraftTheme.subtleGrey),
      WorkoutPhase.ready => ('READY', RowCraftTheme.warningAmber),
      WorkoutPhase.countingDown => ('3...2...1', RowCraftTheme.warningAmber),
      WorkoutPhase.rowing => ('ROWING', RowCraftTheme.successGreen),
      WorkoutPhase.paused => ('PAUSED', RowCraftTheme.warningAmber),
      WorkoutPhase.resting => ('REST', RowCraftTheme.warningAmber),
      WorkoutPhase.finished => ('DONE', RowCraftTheme.primaryBlue),
    };

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
