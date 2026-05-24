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
// Tile display mode (auto-cycle vs locked variants)
// ---------------------------------------------------------------------------

enum TileDisplayMode { auto, primary, secondary }

TileDisplayMode advanceTileMode(TileDisplayMode current) {
  switch (current) {
    case TileDisplayMode.auto:
      return TileDisplayMode.primary;
    case TileDisplayMode.primary:
      return TileDisplayMode.secondary;
    case TileDisplayMode.secondary:
      return TileDisplayMode.auto;
  }
}

bool tileShowsSecondary(TileDisplayMode mode, bool autoShowSecondary) {
  switch (mode) {
    case TileDisplayMode.auto:
      return autoShowSecondary;
    case TileDisplayMode.primary:
      return false;
    case TileDisplayMode.secondary:
      return true;
  }
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
  TileDisplayMode _totalMode = TileDisplayMode.auto;
  TileDisplayMode _paceMode = TileDisplayMode.auto;
  TileDisplayMode _hrMode = TileDisplayMode.auto;
  TileDisplayMode _calMode = TileDisplayMode.auto;
  bool _autoShowSecondary = false;
  Timer? _autoRotateTimer;

  @override
  void initState() {
    super.initState();
    _autoRotateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      // Skip the rebuild when every tile is user-locked — nothing would change.
      final anyAuto = _totalMode == TileDisplayMode.auto ||
          _paceMode == TileDisplayMode.auto ||
          _hrMode == TileDisplayMode.auto ||
          _calMode == TileDisplayMode.auto;
      if (!anyAuto) return;
      setState(() => _autoShowSecondary = !_autoShowSecondary);
    });
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    super.dispose();
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
                  flex: 40,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 5, 6),
                    child: _statGrid(session),
                  ),
                ),
                Expanded(
                  flex: 60,
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
          flex: 4,
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
                  showRemaining:
                      tileShowsSecondary(_totalMode, _autoShowSecondary),
                  isAuto: _totalMode == TileDisplayMode.auto,
                  onTap: () => setState(
                      () => _totalMode = advanceTileMode(_totalMode)),
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
                  showAvg:
                      tileShowsSecondary(_paceMode, _autoShowSecondary),
                  isAuto: _paceMode == TileDisplayMode.auto,
                  onTap: () => setState(
                      () => _paceMode = advanceTileMode(_paceMode)),
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
                  showAvg:
                      tileShowsSecondary(_hrMode, _autoShowSecondary),
                  isAuto: _hrMode == TileDisplayMode.auto,
                  onTap: () => setState(
                      () => _hrMode = advanceTileMode(_hrMode)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CaloriesTile(
                  session: session,
                  showDistance:
                      !tileShowsSecondary(_calMode, _autoShowSecondary),
                  isAuto: _calMode == TileDisplayMode.auto,
                  onTap: () => setState(
                      () => _calMode = advanceTileMode(_calMode)),
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
  /// Auto-cycle indicator state. `null` = no indicator.
  final bool? isAuto;

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
    this.isAuto,
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
              _TileHeaderTrailing(
                trailing: trailing,
                isAuto: isAuto,
                pageIndex: showDots ? pageIndex : null,
                pageCount: showDots ? pageCount : null,
              ),
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

/// Right-side ornaments shared by the tile header row in `_StatTile` and the
/// `_HrTile` phone-only render branch. Renders any present subset of:
/// `trailing` widget → auto-cycle indicator → pagination dots, separated by a
/// 4px gap. Keeps the spacing rules in one place so the two render paths can't
/// drift.
class _TileHeaderTrailing extends StatelessWidget {
  final Widget? trailing;
  final bool? isAuto;
  final int? pageIndex;
  final int? pageCount;

  const _TileHeaderTrailing({
    this.trailing,
    this.isAuto,
    this.pageIndex,
    this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    final showDots =
        pageCount != null && pageCount! > 1 && pageIndex != null;
    final auto = isAuto;
    final ornaments = <Widget>[
      ?trailing,
      if (auto != null) _AutoCycleIndicator(isAuto: auto),
      if (showDots) _PageDots(index: pageIndex!, count: pageCount!),
    ];
    if (ornaments.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < ornaments.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          ornaments[i],
        ],
      ],
    );
  }
}

/// Tiny autorenew glyph shown next to the page dots on auto-cycle-capable
/// tiles. Bright when the tile is in auto mode, faded when the user has
/// locked it to a specific variant.
class _AutoCycleIndicator extends StatelessWidget {
  final bool isAuto;

  const _AutoCycleIndicator({required this.isAuto});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.autorenew,
      size: 12,
      color: isAuto
          ? RowCraftTheme.metricWhite
          : RowCraftTheme.subtleGrey.withValues(alpha: 0.4),
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
      trailing: Text.rich(
        TextSpan(
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: RowCraftTheme.subtleGrey,
          ),
          children: [
            TextSpan(
              text: '$current',
              style: const TextStyle(color: RowCraftTheme.successGreen),
            ),
            TextSpan(text: '/$total'),
          ],
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
  final bool isAuto;
  final VoidCallback onTap;

  const _TotalTile({
    required this.session,
    required this.showRemaining,
    required this.isAuto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = showRemaining ? 'REMAINING' : 'TOTAL TIME';
    final value = showRemaining
        ? remainingWorkoutLabel(session)
        : session.pm5Data.elapsedFormatted;
    return _StatTile(
      label: label,
      value: value,
      onTap: onTap,
      pageIndex: showRemaining ? 1 : 0,
      pageCount: 2,
      isAuto: isAuto,
    );
  }
}

class _TargetPaceTile extends StatelessWidget {
  final WorkoutSessionState session;
  final bool showAvg;
  final bool isAuto;
  final VoidCallback onTap;

  const _TargetPaceTile({
    required this.session,
    required this.showAvg,
    required this.isAuto,
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
        isAuto: isAuto,
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
      isAuto: isAuto,
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
  final bool isAuto;
  final VoidCallback onTap;

  const _HrTile({
    required this.session,
    required this.showAvg,
    required this.isAuto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (showAvg) {
      final avgHr = session.engineState.avgHeartRate;
      return _StatTile(
        label: 'AVG HR',
        value: (avgHr != null && avgHr > 0) ? '$avgHr' : '--',
        unitSuffix: (avgHr != null && avgHr > 0) ? 'bpm' : null,
        leadingWidget:
            const PulsingHeartIcon(color: RowCraftTheme.errorRose),
        onTap: onTap,
        pageIndex: 1,
        pageCount: 2,
        isAuto: isAuto,
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
        isAuto: isAuto,
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
        isAuto: isAuto,
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
                _TileHeaderTrailing(
                  isAuto: isAuto,
                  pageIndex: 0,
                  pageCount: 2,
                ),
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
  final bool isAuto;
  final VoidCallback onTap;

  const _CaloriesTile({
    required this.session,
    required this.showDistance,
    required this.isAuto,
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
      pageIndex: showDistance ? 0 : 1,
      pageCount: 2,
      isAuto: isAuto,
    );
  }
}
