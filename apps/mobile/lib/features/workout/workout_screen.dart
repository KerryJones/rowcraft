import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../models/workout_segment.dart';
import '../ble/ble_provider.dart';
import '../ble/hr_service.dart';
import '../ble/pm5_service.dart';
import 'ftp_result_dialog.dart';
import 'rowing_animation.dart';
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

            // Main metrics area
            Expanded(
              child: _MainMetrics(session: session),
            ),

            // Compact tertiary metrics strip
            _TertiaryStrip(session: session),

            // Interval progress + strip
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
          // HR status (now the primary HR display — removed from main metrics)
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

/// Redesigned main metrics with 3-tier visual hierarchy:
/// 1. Hero split (96px) — THE number
/// 2. Pace guide bar (44px, only when target exists)
/// 3. Animated rower + stroke rate (48px)
class _MainMetrics extends StatelessWidget {
  final WorkoutSessionState session;

  const _MainMetrics({required this.session});

  @override
  Widget build(BuildContext context) {
    final data = session.pm5Data;
    final segment = session.engineState.currentSegment;
    final isActive = session.engineState.phase == WorkoutPhase.rowing ||
        session.engineState.phase == WorkoutPhase.resting;

    // Determine split color based on target
    Color splitColor = RowCraftTheme.metricWhite;
    if (segment?.targetSplit != null && data.pace > 0) {
      final pace = data.pace.toDouble();
      if (pace >= segment!.targetSplit!.min &&
          pace <= segment.targetSplit!.max) {
        splitColor = RowCraftTheme.successGreen;
      } else if (pace > segment.targetSplit!.max) {
        splitColor = RowCraftTheme.warningAmber;
      } else {
        splitColor = RowCraftTheme.accentTeal;
      }
    }

    // Determine stroke rate color based on target
    Color srColor = RowCraftTheme.metricWhite;
    if (segment?.targetStrokeRate != null && data.strokeRate > 0) {
      final sr = data.strokeRate;
      if (sr >= segment!.targetStrokeRate!.min &&
          sr <= segment.targetStrokeRate!.max) {
        srColor = RowCraftTheme.successGreen;
      } else if (sr > segment.targetStrokeRate!.max) {
        srColor = RowCraftTheme.warningAmber;
      } else {
        srColor = RowCraftTheme.accentTeal;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Tier 1: Hero Split — THE number (96px)
          Text(
            data.paceFormatted,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 96,
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

          // Tier 2: Pace guide bar (only when target exists)
          if (segment?.targetSplit != null) ...[
            const SizedBox(height: 12),
            _PaceGuideBar(
              targetMin: segment!.targetSplit!.min,
              targetMax: segment.targetSplit!.max,
              currentPace: data.pace.toDouble(),
            ),
          ],

          const SizedBox(height: 16),

          // Tier 3: Animated rower + stroke rate
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RowingAnimation(
                strokeRate: data.strokeRate,
                isActive: isActive,
                height: 48,
              ),
              const SizedBox(width: 16),
              Text(
                '${data.strokeRate}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: srColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  's/m',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: RowCraftTheme.subtleGrey,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact horizontal strip showing tertiary metrics.
/// Replaces the two rows of 3 large metrics with a single dense strip.
class _TertiaryStrip extends StatelessWidget {
  final WorkoutSessionState session;

  const _TertiaryStrip({required this.session});

  @override
  Widget build(BuildContext context) {
    final data = session.pm5Data;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: RowCraftTheme.surfaceContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TertiaryItem(label: 'DISTANCE', value: data.distanceFormatted),
          _TertiaryItem(label: 'TIME', value: data.elapsedFormatted),
          _TertiaryItem(label: 'WATTS', value: '${data.watts}'),
          _TertiaryItem(label: 'CAL', value: '${data.calories}'),
        ],
      ),
    );
  }
}

class _TertiaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _TertiaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: RowCraftTheme.subtleGrey,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: RowCraftTheme.metricWhite,
          ),
        ),
      ],
    );
  }
}

/// Interval progress with segment-type colors and remaining time/distance.
class _IntervalProgress extends StatelessWidget {
  final WorkoutEngineState engineState;

  const _IntervalProgress({required this.engineState});

  Color _segmentColor(SegmentType? type, WorkoutPhase phase) {
    if (phase == WorkoutPhase.paused) return RowCraftTheme.warningAmber;

    return switch (type) {
      SegmentType.work => RowCraftTheme.segmentWork,
      SegmentType.rest => RowCraftTheme.segmentRest,
      SegmentType.warmup => RowCraftTheme.segmentWarmup,
      SegmentType.cooldown => RowCraftTheme.segmentCooldown,
      null => RowCraftTheme.primaryBlue,
    };
  }

  String _remainingLabel(WorkoutEngineState state) {
    final segment = state.currentSegment;
    if (segment == null) return '';

    switch (segment.durationType) {
      case DurationType.time:
        final totalSec = segment.durationValue.toInt();
        final elapsedSec = state.segmentElapsedTime.inSeconds;
        final remaining = (totalSec - elapsedSec).clamp(0, totalSec);
        final min = remaining ~/ 60;
        final sec = remaining % 60;
        return '$min:${sec.toString().padLeft(2, '0')} left';
      case DurationType.distance:
        final totalM = segment.durationValue;
        final remaining = (totalM - state.segmentElapsedDistance)
            .clamp(0.0, totalM)
            .toInt();
        return '${remaining}m left';
      case DurationType.calories:
        final totalCal = segment.durationValue;
        final remaining = (totalCal - state.segmentElapsedCalories)
            .clamp(0.0, totalCal)
            .round();
        return '${remaining}cal left';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = engineState.segmentProgress;
    final segColor = _segmentColor(
      engineState.currentSegment?.type,
      engineState.phase,
    );
    final isPaused = engineState.phase == WorkoutPhase.paused;

    final phaseLabel = isPaused
        ? 'PAUSED'
        : engineState.currentSegment?.type.name.toUpperCase() ?? 'WORK';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                phaseLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: segColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                _remainingLabel(engineState),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: RowCraftTheme.metricWhite,
                      fontWeight: FontWeight.w600,
                    ),
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
              valueColor: AlwaysStoppedAnimation(segColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact horizontal interval strip — shows previous, current, and next
/// segments in a single row.
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

          // Counter (clamped to valid range at segment boundaries)
          Text(
            '${(currentIndex + 1).clamp(1, segments.length)}/${segments.length}',
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

  Color _segTypeColor(SegmentType type) {
    return switch (type) {
      SegmentType.work => RowCraftTheme.segmentWork,
      SegmentType.rest => RowCraftTheme.segmentRest,
      SegmentType.warmup => RowCraftTheme.segmentWarmup,
      SegmentType.cooldown => RowCraftTheme.segmentCooldown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segColor = _segTypeColor(segment.type);

    final (icon, color) = switch (state) {
      _SegState.completed => (Icons.check, RowCraftTheme.successGreen),
      _SegState.current => (Icons.play_arrow, segColor),
      _SegState.upcoming => (Icons.circle_outlined, RowCraftTheme.subtleGrey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: state == _SegState.current
            ? segColor.withValues(alpha: 0.15)
            : RowCraftTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: state == _SegState.current
            ? Border.all(color: segColor, width: 1)
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

/// Workout controls with PM5 connection guard on START button.
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PM5 guard hint
          if ((phase == WorkoutPhase.idle || phase == WorkoutPhase.ready) &&
              !pm5Connected)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Connect PM5 to start',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RowCraftTheme.subtleGrey,
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
/// - 44px tall, full width — visible in peripheral vision
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
            : RowCraftTheme.accentTeal;

    // Bar background shifts color when out of range (peripheral vision cue)
    final barBgColor = isInRange
        ? RowCraftTheme.successGreen.withValues(alpha: 0.08)
        : isTooSlow
            ? RowCraftTheme.errorRose.withValues(alpha: 0.08)
            : RowCraftTheme.surfaceContainerHigh;

    final zoneLeft =
        ((targetMin - displayMin) / displayRange).clamp(0.0, 1.0);
    final zoneRight =
        ((targetMax - displayMin) / displayRange).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Labels — integrated target range (replaces separate _TargetCallout)
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
          // The guide bar — 44px tall
          SizedBox(
            height: 44,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    // Background track with color-shift
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: width,
                      height: 44,
                      decoration: BoxDecoration(
                        color: barBgColor,
                        borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: RowCraftTheme.successGreen
                                .withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Current pace indicator — thick bar
                    if (currentPace > 0)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 150),
                        left: (pacePosition * width - 4).clamp(
                            0.0,
                            (width - 8)
                                .clamp(0.0, double.infinity)),
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
