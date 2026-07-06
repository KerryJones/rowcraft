
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/adaptive.dart';
import '../../app/theme.dart';
import '../../models/workout_segment.dart';
import '../../services/foreground_session_service.dart';
import '../../services/settings_service.dart';
import '../../utils/pace_utils.dart';
import '../../utils/segment_color.dart';
import '../../utils/hr_zones.dart';
import '../../widgets/hr_zone_badge.dart';
import '../ble/ble_provider.dart';
import '../ble/pm5_service.dart';
import 'ftp_result_screen.dart';
import 'workout_engine.dart';
import 'workout_provider.dart';
import 'widgets/ble_status_bar.dart';
import 'widgets/hero_section.dart';
import 'widgets/session_format.dart';
import 'widgets/workout_controls.dart';
import 'widgets/workout_profile_graph.dart';
import 'workout_screen_compact.dart';
import 'workout_summary_screen.dart';

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

class _WorkoutScreenState extends ConsumerState<WorkoutScreen>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _structuredCompleteShown = false;

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
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ask for notification permission up front (Android 13+) so the
      // foreground service notification is visible once the workout starts.
      ref.read(foregroundSessionServiceProvider).requestPermission();
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
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState != AppLifecycleState.resumed) return;
    // Coming back from background mid-session: if the PM5 link dropped
    // while we were away, kick off a reconnect immediately.
    final session = ref.read(workoutSessionProvider);
    final phase = session.engineState.phase;
    final sessionActive = phase == WorkoutPhase.countingDown ||
        phase == WorkoutPhase.rowing ||
        phase == WorkoutPhase.resting ||
        phase == WorkoutPhase.paused;
    if (!sessionActive) return;
    final bleState = ref.read(bleProvider);
    if (bleState.pm5ConnectionState == PM5ConnectionState.disconnected ||
        bleState.pm5ConnectionState == PM5ConnectionState.error) {
      ref.read(bleProvider.notifier).autoReconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final engineState = session.engineState;

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
          if (isCompactMode) const BluetoothStatusIcon(),
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
            ? (session.calculatedFtp != null
                ? FtpResultScreen(
                    calculatedFtp: session.calculatedFtp!,
                    calculationBasis: session.ftpCalculationBasis ?? '',
                    previousFtpWatts: session.previousFtpWatts,
                    isRamp: session.workoutTags.contains('ramp'),
                    rampStagesCompleted: session.rampStagesCompleted,
                    rampTotalStages: session.rampTotalStages,
                    rampPeakWatts: session.rampPeakWatts,
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
                  WorkoutProfileGraph(
                    session: session,
                    height: isTablet(context) ? 110 : 64,
                  ),

                // Hero section (pace, guide bar, stroke rate)
                Expanded(
                  child: HeroSection(
                    session: session,
                    showRowingAnimation: ref
                            .watch(settingsProvider)
                            .value
                            ?.showRowingAnimation ??
                        true,
                  ),
                ),

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
// Overall Stats Bar — TIME | DIST | CAL | LEFT
// ---------------------------------------------------------------------------

class _OverallStatsBar extends StatelessWidget {
  final WorkoutSessionState session;

  const _OverallStatsBar({required this.session});

  @override
  Widget build(BuildContext context) {
    final data = session.pm5Data;
    final tablet = isTablet(context);

    return Container(
      height: tablet ? 40 : 36,
      color: RowCraftTheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _stat(context, 'TIME', data.elapsedFormatted),
          _stat(context, 'DIST', data.distanceFormatted),
          _stat(context, 'CAL', '${data.calories}'),
          _stat(context, 'LEFT', _remainingWorkout()),
          if (tablet)
            _stat(context, 'AVG /500', _avgPaceFormatted()),
        ],
      ),
    );
  }

  String _remainingWorkout() => remainingWorkoutLabel(session);

  String _avgPaceFormatted() {
    final avg = session.engineState.avgPace;
    return avg > 0 ? formatPace(avg) : '--:--';
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
// Current Segment — merged target + progress + HR
// ---------------------------------------------------------------------------

class _CurrentSegment extends StatelessWidget {
  final WorkoutSessionState session;

  const _CurrentSegment({required this.session});

  // Font size bumps for tablet
  double _paceTargetSize(BuildContext context) => isTablet(context) ? 26 : 22;
  double _spmTargetSize(BuildContext context) => isTablet(context) ? 20 : 16;

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

    final String segmentName;
    if (segment.isRest) {
      segmentName = 'REST';
    } else if (segment.targetHrZone != null) {
      segmentName = zoneDisplayInfo(segment.targetHrZone!, session.zoneSystem)
          .name
          .toUpperCase();
    } else {
      segmentName = 'FREE ROW';
    }

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
                '$segmentName ${segment.durationLabel}'.trim(),
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
                    formatPace(resolveSegmentTargetPace(
                      segment,
                      session.ftpWatts,
                    )),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: _paceTargetSize(context),
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
                      fontSize: _spmTargetSize(context),
                      fontWeight: FontWeight.w600,
                      color: RowCraftTheme.successGreen,
                    ),
                  ),
                const Spacer(),
                // HR indicator
                if (data.heartRate != null && data.heartRate! > 0)
                  Builder(builder: (_) {
                    final hr = data.heartRate!;
                    final maxHr = session.maxHeartRate ?? 190;
                    final restHr = session.restingHeartRate;
                    final zone = segment.targetHrZone ??
                        estimateHrZone(hr, maxHr, restingHr: restHr);
                    final info = zoneDisplayInfo(zone, session.zoneSystem);
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
                        HrZoneBadge(
                          zone: zone,
                          color: info.color,
                          estimated: isEstimated,
                          zoneSystem: session.zoneSystem,
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
                '${formatPace(resolveSegmentTargetPace(next, session.ftpWatts))} /500m',
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

