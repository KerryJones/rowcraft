import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../models/workout_segment.dart';
import '../ble/ble_provider.dart';
import '../ble/hr_service.dart';
import '../ble/pm5_service.dart';
import 'ftp_result_dialog.dart';
import 'metrics_display.dart';
import 'workout_engine.dart';
import 'workout_provider.dart';

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

    return Scaffold(
      backgroundColor: RowCraftTheme.surfaceDark,
      appBar: AppBar(
        title: Text(session.workoutTitle),
        actions: [
          if (engineState.phase != WorkoutPhase.idle)
            _PhaseIndicator(phase: engineState.phase),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // BLE connection status bar
            const _BleStatusBar(),

            // Auto-pause banner
            if (engineState.phase == WorkoutPhase.paused &&
                engineState.isAutoPaused)
              const _AutoPauseBanner(),

            // Pace fail warning (top, impossible to miss)
            if (engineState.secondsOutOfRange > 0)
              _PaceFailWarning(
                secondsOut: engineState.secondsOutOfRange,
                threshold: engineState.paceFailThreshold,
              ),

            // Main metrics area (scrollable if needed)
            Expanded(
              child: _MainMetrics(session: session),
            ),

            // Compact interval strip + progress
            if (engineState.phase == WorkoutPhase.rowing ||
                engineState.phase == WorkoutPhase.resting ||
                engineState.phase == WorkoutPhase.paused) ...[
              _IntervalProgress(engineState: engineState),
              _CompactIntervalStrip(session: session),
            ],

            // Controls
            _WorkoutControls(
              phase: engineState.phase,
              onStart: () =>
                  ref.read(workoutSessionProvider.notifier).start(),
              onPause: () =>
                  ref.read(workoutSessionProvider.notifier).pause(),
              onResume: () =>
                  ref.read(workoutSessionProvider.notifier).resume(),
              onStop: () =>
                  ref.read(workoutSessionProvider.notifier).stop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin connection status bar showing PM5 + HR status during workout.
class _BleStatusBar extends ConsumerWidget {
  const _BleStatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final session = ref.watch(workoutSessionProvider);
    final pm5Connected =
        bleState.pm5ConnectionState == PM5ConnectionState.connected;
    final hrConnected =
        bleState.hrConnectionState == HrConnectionState.connected;
    final hrBpm = session.pm5Data.heartRate;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: RowCraftTheme.surfaceContainer,
      child: Row(
        children: [
          // PM5 status
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
            pm5Connected ? 'PM5' : 'PM5 --',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: pm5Connected
                      ? RowCraftTheme.metricWhite
                      : RowCraftTheme.subtleGrey,
                ),
          ),
          const Spacer(),
          // HR status
          Icon(
            Icons.favorite,
            size: 14,
            color: hrConnected
                ? RowCraftTheme.errorRose
                : RowCraftTheme.subtleGrey,
          ),
          const SizedBox(width: 4),
          Text(
            hrBpm != null ? '$hrBpm bpm' : '--',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: hrConnected
                      ? RowCraftTheme.metricWhite
                      : RowCraftTheme.subtleGrey,
                ),
          ),
        ],
      ),
    );
  }
}

class _MainMetrics extends StatelessWidget {
  final WorkoutSessionState session;

  const _MainMetrics({required this.session});

  @override
  Widget build(BuildContext context) {
    final data = session.pm5Data;
    final segment = session.engineState.currentSegment;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Primary metric: Split time (huge)
          MetricsDisplay(
            value: data.paceFormatted,
            label: '/500M',
            size: MetricSize.hero,
            targetMin: segment?.targetSplit?.min,
            targetMax: segment?.targetSplit?.max,
            currentValue: data.pace.toDouble(),
          ),

          // Pace guide bar — large, prominent target window
          if (segment?.targetSplit != null) ...[
            const SizedBox(height: 8),
            _PaceGuideBar(
              targetMin: segment!.targetSplit!.min,
              targetMax: segment.targetSplit!.max,
              currentPace: data.pace.toDouble(),
            ),
          ],

          const SizedBox(height: 16),

          // Target callout — shows target ranges as text
          if (segment?.targetSplit != null ||
              segment?.targetStrokeRate != null)
            _TargetCallout(segment: segment!),

          if (segment?.targetSplit != null ||
              segment?.targetStrokeRate != null)
            const SizedBox(height: 12),

          // Secondary metrics: SPM with zone bar, distance, time
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    MetricsDisplay(
                      value: data.strokeRate.toString(),
                      label: 'S/M',
                      size: MetricSize.large,
                      targetMin: segment?.targetStrokeRate?.min.toDouble(),
                      targetMax: segment?.targetStrokeRate?.max.toDouble(),
                      currentValue: data.strokeRate.toDouble(),
                    ),
                    // Compact stroke rate zone bar
                    if (segment?.targetStrokeRate != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _MiniZoneBar(
                          min: segment!.targetStrokeRate!.min.toDouble(),
                          max: segment.targetStrokeRate!.max.toDouble(),
                          current: data.strokeRate.toDouble(),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: MetricsDisplay(
                  value: data.distanceFormatted,
                  label: 'DISTANCE',
                  size: MetricSize.large,
                ),
              ),
              Expanded(
                child: MetricsDisplay(
                  value: data.elapsedFormatted,
                  label: 'TIME',
                  size: MetricSize.large,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tertiary metrics row
          Row(
            children: [
              Expanded(
                child: MetricsDisplay(
                  value: data.watts.toString(),
                  label: 'WATTS',
                  size: MetricSize.medium,
                ),
              ),
              Expanded(
                child: MetricsDisplay(
                  value: data.calories.toString(),
                  label: 'CALORIES',
                  size: MetricSize.medium,
                ),
              ),
              Expanded(
                child: MetricsDisplay(
                  value: data.heartRate?.toString() ?? '--',
                  label: 'HR',
                  size: MetricSize.medium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntervalProgress extends StatelessWidget {
  final WorkoutEngineState engineState;

  const _IntervalProgress({required this.engineState});

  @override
  Widget build(BuildContext context) {
    final progress = engineState.segmentProgress;
    final isResting = engineState.phase == WorkoutPhase.resting;
    final isPaused = engineState.phase == WorkoutPhase.paused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPaused
                    ? 'PAUSED'
                    : isResting
                        ? 'REST'
                        : 'WORK',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isPaused
                          ? RowCraftTheme.warningAmber
                          : isResting
                              ? RowCraftTheme.warningAmber
                              : RowCraftTheme.primaryBlue,
                    ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: RowCraftTheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(
                isPaused || isResting
                    ? RowCraftTheme.warningAmber
                    : RowCraftTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact horizontal interval strip — shows previous, current, and next
/// segments in a single row. Replaces the full scrollable list to reclaim
/// vertical space for the metrics and pace guide.
class _CompactIntervalStrip extends StatelessWidget {
  final WorkoutSessionState session;

  const _CompactIntervalStrip({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = session.expandedSegments;
    final currentIndex = session.engineState.currentSegmentIndex;

    if (segments.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: RowCraftTheme.surfaceContainer,
      child: Row(
        children: [
          // Previous (completed)
          if (currentIndex > 0)
            _StripSegment(
              segment: segments[currentIndex - 1],
              state: _SegState.completed,
            ),
          if (currentIndex > 0) const SizedBox(width: 8),

          // Current (active)
          if (currentIndex < segments.length)
            Expanded(
              child: _StripSegment(
                segment: segments[currentIndex],
                state: _SegState.current,
              ),
            ),

          // Next
          if (currentIndex + 1 < segments.length) ...[
            const SizedBox(width: 8),
            _StripSegment(
              segment: segments[currentIndex + 1],
              state: _SegState.upcoming,
            ),
          ],

          const SizedBox(width: 12),

          // Counter
          Text(
            '${currentIndex + 1}/${segments.length}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: RowCraftTheme.subtleGrey,
            ),
          ),
        ],
      ),
    );
  }
}

enum _SegState { completed, current, upcoming }

class _StripSegment extends StatelessWidget {
  final WorkoutSegment segment;
  final _SegState state;

  const _StripSegment({required this.segment, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (state) {
      _SegState.completed => (Icons.check, RowCraftTheme.successGreen),
      _SegState.current => (Icons.play_arrow, RowCraftTheme.primaryBlue),
      _SegState.upcoming => (Icons.circle_outlined, RowCraftTheme.subtleGrey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: state == _SegState.current
            ? RowCraftTheme.primaryBlue.withValues(alpha: 0.15)
            : RowCraftTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: state == _SegState.current
            ? Border.all(color: RowCraftTheme.primaryBlue, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '${segment.type.name.toUpperCase()} ${segment.durationLabel}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: state == _SegState.current
                  ? RowCraftTheme.metricWhite
                  : RowCraftTheme.subtleGrey,
              fontWeight:
                  state == _SegState.current ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutControls extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: switch (phase) {
          WorkoutPhase.idle || WorkoutPhase.ready => [
              _ControlButton(
                icon: Icons.play_arrow,
                label: 'START',
                color: RowCraftTheme.successGreen,
                onPressed: onStart,
                isLarge: true,
              ),
            ],
          WorkoutPhase.countingDown => [
              _ControlButton(
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
                icon: Icons.stop,
                label: 'STOP',
                color: RowCraftTheme.errorRose,
                onPressed: onStop,
                isLarge: false,
              ),
              const SizedBox(width: 32),
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
                onPressed: () => Navigator.of(context).pop(),
                isLarge: true,
              ),
            ],
        },
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
    final size = isLarge ? 72.0 : 56.0;
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
            child: Icon(icon, size: isLarge ? 36 : 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
              ),
        ),
      ],
    );
  }
}

/// Large horizontal pace guide bar — the primary visual pacing instrument.
///
/// Designed for glanceable reading at arm's length on a bouncing erg:
/// - 56px tall, full width — visible in peripheral vision
/// - Green zone shows the target window
/// - Thick indicator slides left (faster) / right (slower)
/// - Background color shifts from green to amber/red when out of range
/// - Labels show FASTER/SLOWER orientation + numeric target range
///
/// For pace: LOWER number = FASTER (left side), HIGHER number = SLOWER (right).
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

    // Display range: 1.5x the target range on each side
    final displayMin = targetMin - range * 1.5;
    final displayMax = targetMax + range * 1.5;
    final displayRange = displayMax - displayMin;

    final pacePosition = currentPace > 0
        ? ((currentPace - displayMin) / displayRange).clamp(0.0, 1.0)
        : 0.5;

    final isInRange = currentPace >= targetMin && currentPace <= targetMax;
    final isTooSlow = currentPace > targetMax;

    final indicatorColor = isInRange
        ? RowCraftTheme.successGreen
        : isTooSlow
            ? RowCraftTheme.errorRose
            : RowCraftTheme.segmentWarmup;

    // Bar background shifts color when out of range (peripheral vision cue)
    final barBgColor = isInRange
        ? RowCraftTheme.successGreen.withValues(alpha: 0.08)
        : isTooSlow
            ? RowCraftTheme.errorRose.withValues(alpha: 0.08)
            : RowCraftTheme.surfaceContainerHigh;

    final zoneLeft = ((targetMin - displayMin) / displayRange).clamp(0.0, 1.0);
    final zoneRight = ((targetMax - displayMin) / displayRange).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('FASTER',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 10, color: RowCraftTheme.subtleGrey)),
              Text(
                '${_fmt(targetMin)} – ${_fmt(targetMax)} /500m',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: RowCraftTheme.successGreen,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text('SLOWER',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 10, color: RowCraftTheme.subtleGrey)),
            ],
          ),
          const SizedBox(height: 6),
          // The guide bar — 56px tall for glanceability
          SizedBox(
            height: 56,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    // Background track with color-shift
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: width,
                      height: 56,
                      decoration: BoxDecoration(
                        color: barBgColor,
                        borderRadius: BorderRadius.circular(16),
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
                          color: RowCraftTheme.successGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: RowCraftTheme.successGreen.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Current pace indicator — thick bar, not a dot
                    if (currentPace > 0)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 150),
                        left: (pacePosition * width - 4).clamp(0.0, (width - 8).clamp(0.0, double.infinity)),
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

  String _fmt(double tenths) {
    final total = tenths.toInt();
    final m = total ~/ 600;
    final r = total % 600;
    return '$m:${(r ~/ 10).toString().padLeft(2, '0')}.${r % 10}';
  }
}

/// Shows the current target pace and stroke rate ranges as prominent text
/// between the main split display and the secondary metrics.
class _TargetCallout extends StatelessWidget {
  final WorkoutSegment segment;

  const _TargetCallout({required this.segment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (segment.targetSplit != null) ...[
            Icon(Icons.speed, size: 16, color: RowCraftTheme.successGreen),
            const SizedBox(width: 6),
            Text(
              'Target: ${_formatSplit(segment.targetSplit!.min)} – ${_formatSplit(segment.targetSplit!.max)}/500m',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: RowCraftTheme.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (segment.targetSplit != null && segment.targetStrokeRate != null)
            const SizedBox(width: 20),
          if (segment.targetStrokeRate != null) ...[
            Icon(Icons.rowing, size: 16, color: RowCraftTheme.primaryBlue),
            const SizedBox(width: 6),
            Text(
              '${segment.targetStrokeRate!.min}–${segment.targetStrokeRate!.max} s/m',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: RowCraftTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatSplit(double tenths) {
    final total = tenths.toInt();
    final minutes = total ~/ 600;
    final remaining = total % 600;
    final seconds = remaining ~/ 10;
    final t = remaining % 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.$t';
  }
}

/// Compact zone bar for stroke rate — shows target range with current
/// position indicator. 32px tall, fits under the SPM number.
class _MiniZoneBar extends StatelessWidget {
  final double min;
  final double max;
  final double current;

  const _MiniZoneBar({
    required this.min,
    required this.max,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final range = max - min;
    if (range <= 0) return const SizedBox.shrink();

    final displayMin = min - range;
    final displayMax = max + range;
    final displayRange = displayMax - displayMin;

    final pos = ((current - displayMin) / displayRange).clamp(0.0, 1.0);
    final zoneLeft = ((min - displayMin) / displayRange).clamp(0.0, 1.0);
    final zoneRight = ((max - displayMin) / displayRange).clamp(0.0, 1.0);
    final isInRange = current >= min && current <= max;

    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              // Track
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: RowCraftTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              // Green zone
              Positioned(
                left: zoneLeft * w,
                width: (zoneRight - zoneLeft) * w,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: RowCraftTheme.successGreen.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              // Indicator
              Positioned(
                left: (pos * w - 3).clamp(0, w - 6),
                top: 1,
                bottom: 1,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: isInRange
                        ? RowCraftTheme.successGreen
                        : RowCraftTheme.warningAmber,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
        color: RowCraftTheme.errorRose.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RowCraftTheme.errorRose, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: RowCraftTheme.errorRose, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Below target pace — stopping in ${remaining}s',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _AutoPauseBanner extends StatelessWidget {
  const _AutoPauseBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: RowCraftTheme.warningAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RowCraftTheme.warningAmber, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline,
              color: RowCraftTheme.warningAmber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Paused — start rowing to resume',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: RowCraftTheme.warningAmber,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(right: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
