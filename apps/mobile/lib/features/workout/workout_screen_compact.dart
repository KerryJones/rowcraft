import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/adaptive.dart';
import '../../app/theme.dart';
import '../../models/workout_segment.dart';
import '../../services/local_db.dart';
import '../../services/settings_service.dart';
import '../../utils/pace_utils.dart';
import '../../utils/hr_zones.dart';
import '../../widgets/hr_zone_badge.dart';
import 'hr_zone_gauge.dart';
import 'widgets/pulsing_heart_icon.dart';
import 'workout_engine.dart';
import 'workout_provider.dart';
import 'workout_screen.dart';

// ---------------------------------------------------------------------------
// Display mode provider
// ---------------------------------------------------------------------------

enum WorkoutDisplayMode { classic, compact }

const _displayModePrefKey = 'workout_display_mode';

class WorkoutDisplayModeNotifier extends StateNotifier<WorkoutDisplayMode?> {
  WorkoutDisplayModeNotifier(this._db) : super(null) {
    _load();
  }

  final LocalDatabase _db;

  Future<void> _load() async {
    final raw = await _db.getSyncMeta(_displayModePrefKey);
    if (raw == null) return; // leave null so UI can pick a size-aware default
    state = WorkoutDisplayMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => WorkoutDisplayMode.classic,
    );
  }

  Future<void> setMode(WorkoutDisplayMode mode) async {
    state = mode;
    await _db.setSyncMeta(_displayModePrefKey, mode.name);
  }
}

final workoutDisplayModeProvider =
    StateNotifierProvider<WorkoutDisplayModeNotifier, WorkoutDisplayMode?>(
        (ref) {
  return WorkoutDisplayModeNotifier(ref.watch(localDatabaseProvider));
});

/// Resolve the effective display mode. If the user has no saved preference,
/// default to compact on phones (shortest side < 600dp) and classic on tablets.
WorkoutDisplayMode effectiveDisplayMode(
  WorkoutDisplayMode? stored,
  BuildContext context,
) {
  if (stored != null) return stored;
  final shortest = MediaQuery.sizeOf(context).shortestSide;
  return shortest < 600 ? WorkoutDisplayMode.compact : WorkoutDisplayMode.classic;
}

// ---------------------------------------------------------------------------
// Compact body
// ---------------------------------------------------------------------------

class WorkoutScreenCompactBody extends ConsumerStatefulWidget {
  final WorkoutSessionState session;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final bool isLocked;

  const WorkoutScreenCompactBody({
    super.key,
    required this.session,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.isLocked,
  });

  @override
  ConsumerState<WorkoutScreenCompactBody> createState() =>
      _WorkoutScreenCompactBodyState();
}

class _WorkoutScreenCompactBodyState
    extends ConsumerState<WorkoutScreenCompactBody> {
  bool _segmentCountUp = false;
  bool _totalShowRemaining = false;
  bool _paceShowAvg = false;
  bool _hrShowAvg = false;
  bool _calShowDistance = true;
  Timer? _calRotateTimer;

  @override
  void initState() {
    super.initState();
    _startCalRotate();
  }

  @override
  void dispose() {
    _calRotateTimer?.cancel();
    super.dispose();
  }

  void _startCalRotate() {
    _calRotateTimer?.cancel();
    _calRotateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _calShowDistance = !_calShowDistance);
    });
  }

  void _onCalTap() {
    setState(() => _calShowDistance = !_calShowDistance);
    _calRotateTimer?.cancel();
    _calRotateTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) _startCalRotate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final engineState = session.engineState;
    final isLandscapePhone =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
            MediaQuery.sizeOf(context).shortestSide < 600;

    final controls = IgnorePointer(
      ignoring: widget.isLocked,
      child: Opacity(
        opacity: widget.isLocked ? 0.4 : 1.0,
        child: WorkoutControls(
          phase: engineState.phase,
          onStart: widget.onStart,
          onPause: widget.onPause,
          onResume: widget.onResume,
          onStop: widget.onStop,
        ),
      ),
    );

    if (isLandscapePhone) {
      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 45,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 5, 6),
                    child: _statGrid(session),
                  ),
                ),
                Expanded(
                  flex: 55,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 10, 10, 6),
                    child: _heroAndGraph(session),
                  ),
                ),
              ],
            ),
          ),
          controls,
        ],
      );
    }

    return Column(
      children: [
        // Top half: 3x2 stat grid
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: _statGrid(session),
          ),
        ),

        // Bottom half: existing hero visuals + segment graph
        Expanded(
          flex: 6,
          child: _heroAndGraph(session),
        ),

        controls,
      ],
    );
  }

  Widget _statGrid(WorkoutSessionState session) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _SegmentTile(
                  session: session,
                  countUp: _segmentCountUp,
                  onTap: () => setState(
                      () => _segmentCountUp = !_segmentCountUp),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TotalTile(
                  session: session,
                  showRemaining: _totalShowRemaining,
                  onTap: () => setState(
                      () => _totalShowRemaining = !_totalShowRemaining),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _TargetPaceTile(
                  session: session,
                  showAvg: _paceShowAvg,
                  onTap: () =>
                      setState(() => _paceShowAvg = !_paceShowAvg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _TargetSpmTile(session: session)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _HrTile(
                  session: session,
                  showAvg: _hrShowAvg,
                  onTap: () =>
                      setState(() => _hrShowAvg = !_hrShowAvg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CaloriesTile(
                  session: session,
                  showDistance: _calShowDistance,
                  onTap: _onCalTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroAndGraph(WorkoutSessionState session) {
    final showRowingAnim =
        ref.watch(settingsProvider).value?.showRowingAnimation ?? true;
    return Column(
      children: [
        Expanded(
          child: HeroSection(
            session: session,
            inlinePaceSuffix: true,
            showRowingAnimation: showRowingAnim,
          ),
        ),
        if (session.expandedSegments.isNotEmpty)
          WorkoutProfileGraph(session: session),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat tiles
// ---------------------------------------------------------------------------

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  /// Optional leading icon shown before the label text.
  final IconData? icon;
  /// Optional color for the leading icon (defaults to subtleGrey).
  final Color? iconColor;
  /// Optional pre-built leading widget — takes priority over [icon].
  final Widget? leadingWidget;
  /// Show pagination dots when this tile has multiple views. 0-based index.
  final int? pageIndex;
  final int? pageCount;
  /// Optional unit suffix displayed after the value in smaller text.
  final String? unitSuffix;
  /// Optional trend arrow shown before the value: '▲' or '▼'.
  final String? chevron;

  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.icon,
    this.iconColor,
    this.leadingWidget,
    this.pageIndex,
    this.pageCount,
    this.unitSuffix,
    this.chevron,
  });

  @override
  Widget build(BuildContext context) {
    final showDots = pageCount != null && pageCount! > 1 && pageIndex != null;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (leadingWidget != null) ...[
                leadingWidget!,
                const SizedBox(width: 3),
              ] else if (icon != null) ...[
                Icon(icon, size: 11, color: iconColor ?? RowCraftTheme.subtleGrey),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: RowCraftTheme.subtleGrey,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              ?trailing,
              if (showDots) ...[
                if (trailing != null) const SizedBox(width: 4),
                _PageDots(index: pageIndex!, count: pageCount!),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (chevron != null) ...[
                Text(
                  chevron!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    color: valueColor ?? RowCraftTheme.metricWhite,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 2),
              ],
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: valueColor ?? RowCraftTheme.metricWhite,
                          height: 1.0,
                        ),
                      ),
                      if (unitSuffix != null) ...[
                        const SizedBox(width: 2),
                        Text(
                          unitSuffix!,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: RowCraftTheme.metricWhite,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

/// Tiny pagination dots (●○○) shown in the top-right of tappable tiles.
class _PageDots extends StatelessWidget {
  final int index;
  final int count;

  const _PageDots({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index
                  ? RowCraftTheme.subtleGrey
                  : RowCraftTheme.subtleGrey.withValues(alpha: 0.3),
            ),
          ),
        );
      }),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final WorkoutSessionState session;
  final bool countUp;
  final VoidCallback onTap;

  const _SegmentTile({
    required this.session,
    required this.countUp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final engineState = session.engineState;
    final segment = engineState.currentSegment ??
        session.expandedSegments.firstOrNull;
    if (segment == null) {
      return const _StatTile(label: 'SEGMENT', value: '--:--');
    }

    final label = countUp ? 'ELAPSED' : 'SEGMENT';
    final (value, suffix) = countUp
        ? _elapsedSegmentLabel(engineState)
        : remainingSegmentLabel(engineState);

    final total = session.expandedSegments.length;
    final current = (engineState.currentSegmentIndex + 1).clamp(1, total);
    return _StatTile(
      label: label,
      value: value,
      unitSuffix: suffix,
      onTap: onTap,
      pageIndex: countUp ? 1 : 0,
      pageCount: 2,
      trailing: Text(
        '$current/$total',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: RowCraftTheme.subtleGrey,
        ),
      ),
    );
  }
}

(String, String?) _elapsedSegmentLabel(WorkoutEngineState state) {
  final segment = state.currentSegment;
  if (segment == null) return ('0:00', null);
  switch (segment.durationType) {
    case DurationType.time:
      final totalSec = segment.durationValue.toInt();
      final elapsed =
          (totalSec * state.segmentProgress).round().clamp(0, totalSec);
      final m = elapsed ~/ 60;
      final s = elapsed % 60;
      return ('$m:${s.toString().padLeft(2, '0')}', null);
    case DurationType.distance:
      return ('${state.segmentElapsedDistance.toInt()}', 'm');
    case DurationType.calories:
      return ('${state.segmentElapsedCalories.round()}', 'cal');
  }
}

class _TotalTile extends StatelessWidget {
  final WorkoutSessionState session;
  final bool showRemaining;
  final VoidCallback onTap;

  const _TotalTile({
    required this.session,
    required this.showRemaining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = showRemaining ? 'REMAINING' : 'TOTAL';
    final value = showRemaining
        ? remainingWorkoutLabel(session)
        : session.pm5Data.elapsedFormatted;
    return _StatTile(
      label: label,
      value: value,
      onTap: onTap,
      pageIndex: showRemaining ? 1 : 0,
      pageCount: 2,
    );
  }
}

class _TargetPaceTile extends StatelessWidget {
  final WorkoutSessionState session;
  final bool showAvg;
  final VoidCallback onTap;

  const _TargetPaceTile({
    required this.session,
    required this.showAvg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final segment = session.engineState.currentSegment ??
        session.expandedSegments.firstOrNull;
    final hasTarget = segment != null && segment.hasTarget;

    if (showAvg) {
      final avgPace = session.engineState.avgPace;
      return _StatTile(
        label: 'AVG PACE',
        value: avgPace > 0 ? formatPace(avgPace) : '--:--',
        unitSuffix: avgPace > 0 ? '/500m' : null,
        onTap: onTap,
        pageIndex: 1,
        pageCount: 2,
      );
    }

    final isResting = session.engineState.phase == WorkoutPhase.resting;
    final isNoTarget = segment != null &&
        !segment.isRest &&
        !segment.hasTarget;
    final noTargetLabel = isNoTarget && segment.durationType == DurationType.time ? 'Free' : 'Row';
    final value = isResting
        ? 'REST'
        : hasTarget
            ? formatPace(resolveSegmentTargetPace(
                  segment,
                  session.ftpWatts,
                ))
            : isNoTarget
                ? noTargetLabel
                : '--:--';

    // Show trend chevron based on current pace vs target.
    String? chevron;
    if (hasTarget && session.pm5Data.pace > 0) {
      final targetPace = resolveSegmentTargetPace(
        segment,
        session.ftpWatts,
      );
      final (acceptMin, acceptMax) = paceAcceptanceRange(targetPace);
      final pace = session.pm5Data.pace.toDouble();
      if (pace > acceptMax) {
        chevron = '\u25B2'; // ▲ too slow (high pace number = slow)
      } else if (pace < acceptMin) {
        chevron = '\u25BC'; // ▼ too fast (low pace number = fast)
      }
    }

    return _StatTile(
      label: 'TARGET PACE',
      value: value,
      valueColor: isResting ? RowCraftTheme.subtleGrey : hasTarget ? RowCraftTheme.successGreen : null,
      unitSuffix: hasTarget && !isResting ? '/500m' : null,
      chevron: isResting ? null : chevron,
      onTap: onTap,
      pageIndex: 0,
      pageCount: 2,
    );
  }
}

class _TargetSpmTile extends StatelessWidget {
  final WorkoutSessionState session;

  const _TargetSpmTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final segment = session.engineState.currentSegment ??
        session.expandedSegments.firstOrNull;
    final target = segment?.targetStrokeRate;
    final isResting = session.engineState.phase == WorkoutPhase.resting;
    return _StatTile(
      label: 'TARGET S/M',
      value: isResting ? 'REST' : target != null ? '$target' : '--',
      unitSuffix: (!isResting && target != null) ? 'SM' : null,
      valueColor: isResting ? RowCraftTheme.subtleGrey : target != null ? RowCraftTheme.successGreen : null,
    );
  }
}

class _HrTile extends StatelessWidget {
  final WorkoutSessionState session;
  final bool showAvg;
  final VoidCallback onTap;

  const _HrTile({
    required this.session,
    required this.showAvg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (showAvg) {
      final avgHr = session.engineState.avgHeartRate;
      // AVG HR variant intentionally stays static — too quick to read against
      // a slowly-changing average.
      return _StatTile(
        label: 'AVG HR',
        value: (avgHr != null && avgHr > 0) ? '$avgHr' : '--',
        unitSuffix: (avgHr != null && avgHr > 0) ? 'bpm' : null,
        leadingWidget:
            const PulsingHeartIcon(color: RowCraftTheme.errorRose),
        onTap: onTap,
        pageIndex: 1,
        pageCount: 2,
      );
    }

    final hr = session.pm5Data.heartRate;
    final hasHr = hr != null && hr > 0;
    final maxHr = session.maxHeartRate ?? 190;

    if (!hasHr) {
      return _StatTile(
        label: 'HR',
        value: '--',
        leadingWidget:
            const PulsingHeartIcon(color: RowCraftTheme.errorRose),
        onTap: onTap,
        pageIndex: 0,
        pageCount: 2,
      );
    }

    if (isTablet(context)) {
      final segment = session.engineState.currentSegment;
      final targetZone = segment?.targetHrZone;
      final restHr = session.restingHeartRate;
      final zone = targetZone ?? estimateHrZone(hr, maxHr, restingHr: restHr);
      final info = zoneDisplayInfo(zone, session.zoneSystem);
      return _StatTile(
        label: 'HR',
        value: '$hr',
        valueColor: info.color,
        unitSuffix: 'bpm',
        leadingWidget:
            PulsingHeartIcon(bpm: hr, color: RowCraftTheme.errorRose),
        trailing: HrZoneBadge(
          zone: zone,
          color: info.color,
          estimated: targetZone == null,
          zoneSystem: session.zoneSystem,
        ),
        onTap: onTap,
        pageIndex: 0,
        pageCount: 2,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: RowCraftTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PulsingHeartIcon(bpm: hr, color: RowCraftTheme.errorRose),
                const SizedBox(width: 3),
                Text(
                  'HR',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: RowCraftTheme.subtleGrey,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                const _PageDots(index: 0, count: 2),
              ],
            ),
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -6),
                  child: HrZoneGauge(
                    bpm: hr,
                    maxHr: maxHr,
                    restingHr: session.restingHeartRate,
                    zoneSystem: session.zoneSystem,
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

class _CaloriesTile extends StatelessWidget {
  final WorkoutSessionState session;
  final bool showDistance;
  final VoidCallback onTap;

  const _CaloriesTile({
    required this.session,
    required this.showDistance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = showDistance ? 'DISTANCE' : 'CALORIES';
    final value = showDistance
        ? session.pm5Data.distanceFormatted
        : '${session.pm5Data.calories}';
    return _StatTile(
      label: label,
      value: value,
      icon: showDistance ? Icons.straighten : Icons.local_fire_department,
      iconColor: showDistance ? null : const Color(0xFFFF9800),
      onTap: onTap,
      pageIndex: showDistance ? 1 : 0,
      pageCount: 2,
    );
  }
}
