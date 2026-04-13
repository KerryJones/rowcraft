import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/theme.dart';
import '../../models/workout_segment.dart';
import '../../models/workout_time_sample.dart';
import '../../services/audio_service.dart';
import '../../utils/pace_utils.dart';
import '../../utils/workout_utils.dart';
import '../../utils/segment_color.dart';
import '../ble/ble_provider.dart';
import '../ble/pm5_service.dart';
import 'ftp_result_screen.dart';
import 'hr_zone_gauge.dart';
import 'rowing_animation.dart';
import 'workout_engine.dart';
import 'workout_provider.dart';
import 'workout_screen_compact.dart';
import 'workout_summary_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------


/// Format pace tenths to M:SS
String formatPaceTenths(double tenths) {
  final total = tenths.toInt();
  if (total == 0) return '--:--';
  final m = total ~/ 600;
  final r = total % 600;
  return '$m:${(r ~/ 10).toString().padLeft(2, '0')}';
}


/// Pace acceptance range with 5% tolerance around target pace.
/// Determines color feedback and TOO SLOW / TOO FAST warnings.
(double, double) paceAcceptanceRange(int targetPace) {
  final tolerance = targetPace * 0.05;
  return (targetPace - tolerance, targetPace + tolerance);
}

/// Remaining workout time, formatted M:SS. Sums per-segment effective
/// durations across the unfinished portion of the workout.
String remainingWorkoutLabel(WorkoutSessionState session) {
  final segments = session.expandedSegments;
  if (segments.isEmpty) return '--:--';

  final ftpWatts = session.ftpWatts;
  final durations =
      segments.map((s) => effectiveDuration(s, ftpWatts)).toList();
  final totalDuration = durations.fold<double>(0, (a, b) => a + b);
  if (totalDuration <= 0) return '--:--';

  final currentIndex = session.engineState.currentSegmentIndex;
  var elapsed = 0.0;
  for (var i = 0; i < currentIndex && i < durations.length; i++) {
    elapsed += durations[i];
  }
  if (currentIndex < durations.length) {
    elapsed += session.engineState.segmentProgress * durations[currentIndex];
  }

  final remainingSec =
      ((totalDuration - elapsed).clamp(0, totalDuration)).round();
  final m = remainingSec ~/ 60;
  final s = remainingSec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
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
  bool _isLocked = false;
  bool _structuredCompleteShown = false;
  int _lastBeepSecond = -1;
  int _lastBeepSegmentIndex = -1;

  void _showCompletionModal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: RowCraftTheme.surfaceContainer,
        title: Text(
          'Workout Complete!',
          style: GoogleFonts.inter(
            color: RowCraftTheme.metricWhite,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'All segments finished. What would you like to do?',
          style: GoogleFonts.inter(color: RowCraftTheme.subtleGrey),
        ),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(workoutSessionProvider.notifier).continueWithFreeRow();
                  },
                  icon: const Icon(Icons.rowing, size: 24),
                  label: Text(
                    'Keep Rowing',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref
                        .read(workoutSessionProvider.notifier)
                        .finishFromStructuredComplete();
                  },
                  icon: const Icon(Icons.save, size: 24),
                  label: Text(
                    'Save Workout',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RowCraftTheme.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(workoutSessionProvider.notifier).discardResult();
                    if (context.mounted) context.go('/');
                  },
                  icon: const Icon(Icons.delete_outline, size: 24),
                  label: Text(
                    'Discard',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RowCraftTheme.errorRose,
                    side: const BorderSide(color: RowCraftTheme.errorRose, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _checkCountdownBeep(WorkoutEngineState es) {
    final seg = es.currentSegment;
    if (seg == null) return;
    final phase = es.phase;
    if (phase != WorkoutPhase.rowing && phase != WorkoutPhase.resting) return;
    if (seg.durationType != DurationType.time) return;

    final remaining =
        seg.durationValue.toInt() - es.segmentElapsedTime.inSeconds;
    if (remaining > 3 || remaining < 0) {
      // Reset when we enter a new segment or are far from transition.
      if (es.currentSegmentIndex != _lastBeepSegmentIndex) {
        _lastBeepSegmentIndex = es.currentSegmentIndex;
        _lastBeepSecond = -1;
      }
      return;
    }
    if (remaining == _lastBeepSecond &&
        es.currentSegmentIndex == _lastBeepSegmentIndex) {
      return; // Already beeped for this second
    }
    _lastBeepSecond = remaining;
    _lastBeepSegmentIndex = es.currentSegmentIndex;
    AudioService.instance.playCountdownBeep(remaining);
  }

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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  icon: const Icon(Icons.rowing, size: 24),
                  label: Text(
                    'Keep Going',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    onConfirmed();
                  },
                  icon: const Icon(Icons.stop, size: 24),
                  label: Text(
                    'End Workout',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RowCraftTheme.errorRose,
                    side: const BorderSide(color: RowCraftTheme.errorRose, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
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
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final engineState = session.engineState;

    // Segment transition countdown beeps (time-based segments only)
    _checkCountdownBeep(engineState);

    // Show completion modal when structured workout ends.
    // For FTP tests, skip the modal and auto-finish to go straight to results.
    if (engineState.phase == WorkoutPhase.structuredComplete &&
        !_structuredCompleteShown) {
      _structuredCompleteShown = true;
      if (session.workoutTags.contains('ftp')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(workoutSessionProvider.notifier).finishFromStructuredComplete();
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showCompletionModal(context);
        });
      }
    }
    if (engineState.phase != WorkoutPhase.structuredComplete) {
      _structuredCompleteShown = false;
    }

    final isActive = engineState.phase == WorkoutPhase.rowing ||
        engineState.phase == WorkoutPhase.resting ||
        engineState.phase == WorkoutPhase.paused;

    final storedDisplayMode = ref.watch(workoutDisplayModeProvider);
    final displayMode = effectiveDisplayMode(storedDisplayMode, context);
    final isCompactMode = displayMode == WorkoutDisplayMode.compact;

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
          // In compact mode show a BT icon replacing the inline BleStatusBar.
          if (isCompactMode) const _BluetoothStatusIcon(),
          IconButton(
            icon: Icon(
              isCompactMode
                  ? Icons.view_agenda_outlined
                  : Icons.dashboard_outlined,
              size: 20,
              color: RowCraftTheme.subtleGrey,
            ),
            tooltip: isCompactMode ? 'Classic layout' : 'Compact layout',
            onPressed: () {
              ref.read(workoutDisplayModeProvider.notifier).setMode(
                    isCompactMode
                        ? WorkoutDisplayMode.classic
                        : WorkoutDisplayMode.compact,
                  );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40),
          ),
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
            ? (session.showFtpDialog && session.calculatedFtp != null
                ? FtpResultScreen(
                    calculatedFtp: session.calculatedFtp!,
                    calculationBasis: session.ftpCalculationBasis ?? '',
                    previousFtpWatts: session.previousFtpWatts,
                    isRamp: session.workoutTags.contains('ramp'),
                    rampStagesCompleted: session.rampStagesCompleted,
                    rampTotalStages: session.rampTotalStages,
                    rampPeakWatts: session.rampPeakWatts,
                    onSave: (watts) {
                      ref.read(workoutSessionProvider.notifier).saveFtp(watts);
                    },
                    onSkip: () {
                      ref.read(workoutSessionProvider.notifier).dismissFtpDialog();
                    },
                  )
                : const WorkoutSummaryContent())
            : Stack(
          children: [
            // Main layout
            if (isCompactMode)
              WorkoutScreenCompactBody(
                session: session,
                isLocked: _isLocked,
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
              )
            else
              Column(
              children: [
                // BLE status
                const BleStatusBar(),

                // Overall stats (time, distance, calories)
                _OverallStatsBar(session: session),

                // Workout profile graph
                if (session.expandedSegments.isNotEmpty)
                  WorkoutProfileGraph(session: session),

                // Hero section (pace, guide bar, stroke rate)
                Expanded(child: HeroSection(session: session)),

                // Current segment (merged target + progress)
                _CurrentSegment(session: session),

                // Up-next preview
                _UpNextPreview(session: session),

                // Controls (wrapped in IgnorePointer when locked)
                IgnorePointer(
                  ignoring: _isLocked,
                  child: Opacity(
                    opacity: _isLocked ? 0.4 : 1.0,
                    child: WorkoutControls(
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
              Positioned(
                top: 36,
                left: 0,
                right: 0,
                child: _AutoPauseBanner(
                  countdown: engineState.autoPauseCountdown,
                ),
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

class BleStatusBar extends ConsumerWidget {
  const BleStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final connState = bleState.pm5ConnectionState;
    final isConnected = connState == PM5ConnectionState.connected;
    final isReconnecting = connState == PM5ConnectionState.connecting;

    final Color dotColor;
    final Color bgColor;
    final String label;

    if (isConnected) {
      dotColor = RowCraftTheme.successGreen;
      bgColor = RowCraftTheme.surfaceContainer;
      label = 'Rower';
    } else if (isReconnecting) {
      dotColor = RowCraftTheme.warningAmber;
      bgColor = RowCraftTheme.warningAmber.withValues(alpha: 0.15);
      label = 'Reconnecting...';
    } else if (connState == PM5ConnectionState.error) {
      dotColor = RowCraftTheme.errorRose;
      bgColor = RowCraftTheme.errorRose.withValues(alpha: 0.15);
      label = 'Connection error';
    } else {
      dotColor = RowCraftTheme.errorRose;
      bgColor = RowCraftTheme.errorRose.withValues(alpha: 0.15);
      label = 'Rower disconnected';
    }

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: bgColor,
      child: Row(
        children: [
          if (isReconnecting)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: RowCraftTheme.warningAmber,
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isConnected
                  ? RowCraftTheme.metricWhite
                  : dotColor,
            ),
          ),
          if (!isConnected && !isReconnecting) ...[
            const Spacer(),
            GestureDetector(
              onTap: () => ref.read(bleProvider.notifier).autoReconnect(),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  color: RowCraftTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bluetooth Status Icon — compact AppBar indicator (replaces BleStatusBar)
// ---------------------------------------------------------------------------

class _BluetoothStatusIcon extends ConsumerWidget {
  const _BluetoothStatusIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(bleProvider).pm5ConnectionState;
    final Color color;
    if (connState == PM5ConnectionState.connected) {
      color = RowCraftTheme.successGreen;
    } else if (connState == PM5ConnectionState.connecting) {
      color = RowCraftTheme.warningAmber;
    } else {
      color = RowCraftTheme.errorRose;
    }
    return IconButton(
      icon: Icon(Icons.bluetooth, size: 20, color: color),
      tooltip: 'Devices',
      onPressed: () => GoRouter.of(context).push('/devices'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36),
    );
  }
}

// ---------------------------------------------------------------------------
// Overall Stats Bar — TIME | DIST | CAL | LEFT
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
          _stat(context, 'LEFT', _remainingWorkout()),
        ],
      ),
    );
  }

  String _remainingWorkout() => remainingWorkoutLabel(session);

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

class WorkoutProfileGraph extends StatelessWidget {
  final WorkoutSessionState session;

  const WorkoutProfileGraph({super.key, required this.session});

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
          timeSamples: session.timeSamples,
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

  _WorkoutProfilePainter({
    required this.segments,
    required this.currentIndex,
    required this.segmentProgress,
    required this.phase,
    required this.ftpWatts,
    this.timeSamples,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    const barGap = 1.5;
    const minHeightFraction = 0.15;

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

    // Y-axis pace reference lines (faint grid for context)
    {
      final gridPaint = Paint()
        ..color = RowCraftTheme.subtleGrey.withValues(alpha: 0.15)
        ..strokeWidth = 0.5;
      final paceRange = paceMax - paceMin;
      if (paceRange > 0) {
        // Draw lines at ~30s/500m intervals within the pace range
        const intervalTenths = 300; // 30 seconds in tenths
        final startPace = ((paceMin / intervalTenths).ceil() * intervalTenths).toInt();
        for (var pace = startPace; pace <= paceMax; pace += intervalTenths) {
          final normalized = 1 - (pace - paceMin) / paceRange;
          final heightFrac = minHeightFraction + normalized * (1 - minHeightFraction);
          final y = size.height - heightFrac * size.height;
          canvas.drawLine(
            Offset(0, y),
            Offset(size.width, y),
            gridPaint,
          );
          // Pace label (skip if it would clip above canvas)
          final tp = TextPainter(
            text: TextSpan(
              text: formatPaceTenths(pace.toDouble()),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                color: RowCraftTheme.subtleGrey.withValues(alpha: 0.4),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final labelY = y - tp.height - 1;
          if (labelY >= 0) {
            tp.paint(canvas, Offset(1, labelY));
          }
        }
      }
    }

    // Draw pace tracking line (white polyline showing actual pace vs target)
    if (timeSamples != null && timeSamples!.isNotEmpty) {
      // Build segment X-position lookup: for each segment, store its start X and width.
      final segStarts = <double>[];
      final segWidths = <double>[];
      var sx = 0.0;
      for (var i = 0; i < segments.length; i++) {
        segStarts.add(sx);
        final w = math.max(2.0, (durations[i] / totalDuration) * availableWidth);
        segWidths.add(w);
        sx += w + barGap;
      }

      // Build actual timestamp ranges per segment from samples (not from
      // effectiveDuration, which is an estimate for distance/calorie segments).
      final segFirstTs = List<double>.filled(segments.length, 0);
      final segLastTs = List<double>.filled(segments.length, 0);
      final segSeen = List<bool>.filled(segments.length, false);
      for (final sample in timeSamples!) {
        final si = sample.segmentIndex;
        if (si < 0 || si >= segments.length) continue;
        final ts = sample.timestamp.inSeconds.toDouble();
        if (!segSeen[si]) {
          segFirstTs[si] = ts;
          segLastTs[si] = ts;
          segSeen[si] = true;
        } else {
          segLastTs[si] = ts;
        }
      }

      final pacePath = Path();
      var started = false;
      final paceRange = paceMax - paceMin;
      Offset? lastPacePoint;

      for (final sample in timeSamples!) {
        if (sample.pace <= 0) continue;
        final si = sample.segmentIndex;
        if (si < 0 || si >= segments.length) continue;
        // Skip rest segments
        if (segments[si].isRest) {
          started = false;
          continue;
        }

        // X: position within the segment bar using actual timestamps
        final segDurActual = segLastTs[si] - segFirstTs[si];
        final double segFrac;
        if (segDurActual > 0) {
          segFrac = ((sample.timestamp.inSeconds - segFirstTs[si]) / segDurActual).clamp(0.0, 1.0);
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
        lastPacePoint = Offset(px, py);
      }

      canvas.drawPath(
        pacePath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );

      // Draw playhead dot at the last pace point (Zwift-style)
      if (lastPacePoint != null &&
          phase != WorkoutPhase.idle &&
          phase != WorkoutPhase.finished &&
          phase != WorkoutPhase.structuredComplete) {
        // Subtle glow
        canvas.drawCircle(
          lastPacePoint,
          8,
          Paint()..color = Colors.white.withValues(alpha: 0.15),
        );
        // White dot
        canvas.drawCircle(
          lastPacePoint,
          4,
          Paint()..color = RowCraftTheme.metricWhite,
        );
      }
    }

    // Draw playhead dot (fallback when no pace data yet)
    if ((timeSamples == null || timeSamples!.isEmpty) &&
        phase != WorkoutPhase.idle &&
        phase != WorkoutPhase.finished &&
        phase != WorkoutPhase.structuredComplete) {
      final fallback = Offset(playheadX, size.height * 0.5);
      canvas.drawCircle(
        fallback,
        8,
        Paint()..color = Colors.white.withValues(alpha: 0.15),
      );
      canvas.drawCircle(
        fallback,
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
        old.timeSamples != timeSamples;
  }
}

// ---------------------------------------------------------------------------
// Current Segment — merged target + progress + HR
// ---------------------------------------------------------------------------

/// Remaining label for segment countdown.
/// Returns (value, unitSuffix) so the unit can be styled separately.
(String, String?) remainingSegmentLabel(WorkoutEngineState state) {
  final segment = state.currentSegment;
  if (segment == null) return ('', null);

  switch (segment.durationType) {
    case DurationType.time:
      final totalSec = segment.durationValue.toInt();
      final remaining =
          (totalSec * (1 - state.segmentProgress)).round().clamp(0, totalSec);
      final min = remaining ~/ 60;
      final sec = remaining % 60;
      return ('$min:${sec.toString().padLeft(2, '0')}', null);
    case DurationType.distance:
      final totalM = segment.durationValue;
      final remaining =
          (totalM - state.segmentElapsedDistance).clamp(0.0, totalM).toInt();
      return ('$remaining', 'm');
    case DurationType.calories:
      final totalCal = segment.durationValue;
      final remaining = (totalCal - state.segmentElapsedCalories)
          .clamp(0.0, totalCal)
          .round();
      return ('$remaining', 'cal');
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

    final hasPaceTarget = segment.hasTarget;
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
                '${segment.isRest ? 'REST' : segment.targetHrZone != null ? 'Z${segment.targetHrZone}' : 'FREE ROW'} ${segment.durationLabel}'.trim(),
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
              if (isActive) ...[
                Builder(builder: (_) {
                  final (val, suffix) = remainingSegmentLabel(engineState);
                  return Text.rich(
                    TextSpan(children: [
                      TextSpan(text: val),
                      if (suffix != null)
                        TextSpan(
                          text: suffix,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: RowCraftTheme.subtleGrey,
                          ),
                        ),
                    ]),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: RowCraftTheme.subtleGrey,
                    ),
                  );
                }),
              ],
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
                    formatPaceTenths(resolveSegmentTargetPace(
                      segment,
                      session.ftpWatts,
                    ).toDouble()),
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
                    '${segment.targetStrokeRate!} s/m',
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
                        estimateHrZone(hr,
                            maxHr: session.maxHeartRate ?? 190);
                    final info = hrZoneInfo(zone);
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

class HeroSection extends StatelessWidget {
  final WorkoutSessionState session;
  /// When true, inline the "/500m" suffix on the pace row to save vertical space.
  final bool inlinePaceSuffix;

  const HeroSection({super.key, required this.session, this.inlinePaceSuffix = false});

  @override
  Widget build(BuildContext context) {
    final data = session.pm5Data;
    final segment = session.engineState.currentSegment;

    // Pace color based on target — uses 5% tolerance range for feedback
    Color splitColor = RowCraftTheme.metricWhite;
    final paceTarget = segment != null
        ? resolveSegmentTargetPace(segment, session.ftpWatts)
        : 0;
    if (paceTarget > 0 && data.pace > 0) {
      final targetPace = paceTarget;
      final (acceptMin, acceptMax) = paceAcceptanceRange(targetPace);
      final pace = data.pace.toDouble();
      if (pace >= acceptMin && pace <= acceptMax) {
        splitColor = RowCraftTheme.successGreen;
      } else if (pace > acceptMax) {
        splitColor = RowCraftTheme.warningAmber;
      } else {
        splitColor = RowCraftTheme.accentTeal;
      }
    }

    // Stroke rate color + chevron direction — ±1 s/m tolerance around midpoint
    final hasStrokeTarget = segment?.targetStrokeRate != null;
    Color srColor = RowCraftTheme.metricWhite;
    String? srChevron; // null = in range, '▲' = speed up, '▼' = slow down
    if (hasStrokeTarget && data.strokeRate > 0) {
      final sr = data.strokeRate;
      final srTarget = segment!.targetStrokeRate!;
      if (sr >= srTarget - 1 && sr <= srTarget + 1) {
        srColor = RowCraftTheme.successGreen;
      } else if (sr < srTarget - 1) {
        srColor = RowCraftTheme.warningAmber;
        srChevron = '\u25B2'; // ▲ speed up
      } else {
        srColor = RowCraftTheme.errorRose;
        srChevron = '\u25BC'; // ▼ slow down
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Three sizing tiers to prevent overflow on short phones.
        final isTiny = constraints.maxHeight < 170;
        final isSmall = constraints.maxHeight < 260;
        final paceFontSize = isTiny ? 52.0 : isSmall ? 60.0 : 80.0;
        final srFontSize = isTiny ? 30.0 : isSmall ? 36.0 : 44.0;
        final animHeight = isTiny ? 40.0 : isSmall ? 50.0 : 70.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hero pace — centered with /500m suffix offset to the right
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Invisible counterweight so pace number stays centered
                    Opacity(
                      opacity: 0,
                      child: Text(
                        '/500m',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data.paceFormatted,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: paceFontSize,
                        fontWeight: FontWeight.w700,
                        color: splitColor,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/500m',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: RowCraftTheme.subtleGrey,
                          ),
                    ),
                  ],
                ),
              ),

              // Pace guide bar
              if (segment != null && segment.hasTarget) ...[
                const SizedBox(height: 10),
                Builder(builder: (_) {
                  final targetPace = resolveSegmentTargetPace(
                    segment,
                    session.ftpWatts,
                  ).toDouble();
                  return _PaceGuideBar(
                    targetPace: targetPace,
                    currentPace: data.pace.toDouble(),
                  );
                }),
              ],

              // Rowing animation — only shown when segment has a target s/m
              if (segment?.targetStrokeRate != null) ...[
                const SizedBox(height: 8),
                RowingAnimation(
                  strokeRate: segment!.targetStrokeRate!,
                  isActive: true,
                  height: animHeight,
                ),
              ],

              const SizedBox(height: 8),

              // Stroke rate — centered with invisible counterweight
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Invisible counterweight so number stays centered
                    Opacity(
                      opacity: 0,
                      child: Text(
                        's/m',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(width: 6),
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
  final double targetPace;
  final double currentPace;

  const _PaceGuideBar({
    required this.targetPace,
    required this.currentPace,
  });

  @override
  Widget build(BuildContext context) {
    // Derive acceptance window (5% tolerance) for both feedback and visual zone
    final (acceptMin, acceptMax) = paceAcceptanceRange(targetPace.toInt());
    final toleranceRange = acceptMax - acceptMin;

    // Display range is 4× the tolerance window centred on target
    final displayMin = acceptMin - toleranceRange * 1.5;
    final displayMax = acceptMax + toleranceRange * 1.5;
    final displayRange = displayMax - displayMin;
    if (displayRange <= 0) return const SizedBox.shrink();

    // Invert: slow (high pace) on left, fast (low pace) on right
    final pacePosition = currentPace > 0
        ? (1.0 - ((currentPace - displayMin) / displayRange).clamp(0.0, 1.0))
        : 0.5;

    final isInRange = currentPace >= acceptMin && currentPace <= acceptMax;
    final isTooSlow = currentPace > acceptMax;

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
        (1.0 - ((acceptMax - displayMin) / displayRange).clamp(0.0, 1.0));
    final zoneRight =
        (1.0 - ((acceptMin - displayMin) / displayRange).clamp(0.0, 1.0));

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
    final es = session.engineState;
    final isActive = es.phase == WorkoutPhase.rowing ||
        es.phase == WorkoutPhase.resting ||
        es.phase == WorkoutPhase.paused;
    final currentIndex = isActive ? es.currentSegmentIndex : 0;
    final nextIndex = currentIndex + 1;

    // Compute fade-in opacity: invisible when >60s remaining, fully visible
    // in the last few seconds. For non-time segments, use progress.
    double opacity = 0.0;
    if (isActive) {
      final seg = es.currentSegment;
      if (seg != null && seg.durationType == DurationType.time) {
        final remaining =
            seg.durationValue - es.segmentElapsedTime.inSeconds;
        if (remaining <= 60) {
          opacity = ((60 - remaining) / 60).clamp(0.0, 1.0);
        }
      } else {
        // Distance/calorie segments: fade in when progress > 0.85
        if (es.segmentProgress > 0.85) {
          opacity =
              ((es.segmentProgress - 0.85) / 0.15).clamp(0.0, 1.0);
        }
      }
    }

    // Last segment — show "FINAL SEGMENT" (only when active)
    if (nextIndex >= segments.length) {
      if (!isActive) return const SizedBox.shrink();
      return Opacity(
        opacity: opacity,
        child: Container(
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
        ),
      );
    }

    final next = segments[nextIndex];
    final nextColor = segmentDisplayColor(next);

    return Opacity(
      opacity: opacity,
      child: Container(
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
            if (next.hasTarget)
              Text(
                '${formatPaceTenths(resolveSegmentTargetPace(next, session.ftpWatts).toDouble())} /500m',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: nextColor,
                ),
              ),
            if (next.targetStrokeRate != null) ...[
              if (next.hasTarget)
                const SizedBox(width: 8),
              Text(
                '${next.targetStrokeRate!} s/m',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: nextColor,
                ),
              ),
            ],
            // Fallback: show label when no targets exist
            if (next.isRest || (!next.hasTarget && next.targetStrokeRate == null))
              Text(
                next.isRest ? 'REST' : 'FREE ROW',
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Workout Controls (80px)
// ---------------------------------------------------------------------------

class WorkoutControls extends ConsumerWidget {
  final WorkoutPhase phase;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const WorkoutControls({
    super.key,
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
              WorkoutPhase.structuredComplete ||
              WorkoutPhase.finished => [
                  _ControlButton(
                    icon: Icons.home,
                    label: 'HOME',
                    color: RowCraftTheme.subtleGrey,
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
  final int countdown;
  const _AutoPauseBanner({this.countdown = 0});

  @override
  Widget build(BuildContext context) {
    final message = countdown > 0
        ? 'Test ending in ${countdown}s — row to continue'
        : 'Paused — start rowing to resume';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: countdown > 0
            ? RowCraftTheme.errorRose.withValues(alpha: 0.9)
            : RowCraftTheme.warningAmber.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            countdown > 0
                ? Icons.timer_outlined
                : Icons.pause_circle_outline,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
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

