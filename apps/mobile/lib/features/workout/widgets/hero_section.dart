// Hero metrics (pace, guide bar, stroke rate) shared by both screens.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../utils/pace_utils.dart';
import '../rowing_animation.dart';
import '../workout_engine.dart';
import '../workout_provider.dart';
import 'session_format.dart';

// ---------------------------------------------------------------------------
// Hero Section — pace, guide bar, stroke rate
// ---------------------------------------------------------------------------

enum HeroAlign { center, end }

class HeroSection extends StatelessWidget {
  final WorkoutSessionState session;
  /// When true, inline the "/500m" suffix on the pace row to save vertical space.
  final bool inlinePaceSuffix;
  /// When false, suppress the rowing animation even if the current segment has
  /// a target stroke rate. Controlled by user setting.
  final bool showRowingAnimation;
  final HeroAlign verticalAlign;

  const HeroSection({
    super.key,
    required this.session,
    this.inlinePaceSuffix = false,
    this.showRowingAnimation = true,
    this.verticalAlign = HeroAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final data = session.pm5Data;
    final segment = session.engineState.currentSegment;
    final phase = session.engineState.phase;
    final countdown = session.engineState.startCountdown;
    final isCountingDown =
        phase == WorkoutPhase.countingDown && countdown > 0;

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
        final isWide = constraints.maxWidth > 600;
        final paceFontSize = isTiny ? 52.0 : isSmall ? 60.0 : isWide ? 100.0 : 80.0;
        final srFontSize = isTiny ? 30.0 : isSmall ? 36.0 : isWide ? 56.0 : 44.0;
        final animHeight = isTiny ? 40.0 : isSmall ? 50.0 : 70.0;

        // In the stacked phone branch the invisible "/500m" counterweight
        // mirrors the visible suffix so the pace digits stay optically centered.
        // While the 3-2-1 START countdown is running we swap the pace digits
        // for the countdown number — same font, same weight, supersized —
        // so the user can settle on the seat without scanning for the cue.
        Widget paceDisplay() {
          if (isCountingDown) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$countdown',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: paceFontSize * 1.6,
                  fontWeight: FontWeight.w700,
                  color: RowCraftTheme.warningAmber,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
            );
          }
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (!isWide) ...[
                  Opacity(
                    opacity: 0,
                    child: Text(
                      '/500m',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
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
          );
        }

        // Stroke rate display widget (reused in both layouts)
        Widget strokeRateDisplay() => FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
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
                    'SM',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(
                          color: RowCraftTheme.subtleGrey,
                        ),
                  ),
                ],
              ),
            );

        // Guide bar widget
        Widget? guideBar() {
          if (segment == null || !segment.hasTarget) return null;
          final targetPace = resolveSegmentTargetPace(
            segment,
            session.ftpWatts,
          ).toDouble();
          return _PaceGuideBar(
            targetPace: targetPace,
            currentPace: data.pace.toDouble(),
          );
        }

        // Rowing animation widget
        Widget? rowingAnim() {
          if (!showRowingAnimation) return null;
          if (segment?.targetStrokeRate == null) return null;
          return RowingAnimation(
            strokeRate: segment!.targetStrokeRate!,
            isActive: true,
            height: animHeight,
          );
        }

        final guide = guideBar();
        final anim = rowingAnim();

        if (isWide) {
          // Tablet: pace and stroke rate side-by-side. During the START
          // countdown the giant amber digit owns the row — the live stroke
          // rate is irrelevant (rower hasn't started), and "0 SM" beside the
          // countdown reads as a broken half-state.
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isCountingDown
                    ? Center(child: paceDisplay())
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          paceDisplay(),
                          strokeRateDisplay(),
                        ],
                      ),
                if (guide != null) ...[
                  const SizedBox(height: 10),
                  guide,
                ],
                if (anim != null) ...[
                  const SizedBox(height: 8),
                  anim,
                ],
              ],
            ),
          );
        }

        // Narrow container (phone portrait + landscape compact, where the
        // hero column only gets ~60% width): stack so SM can't get pushed
        // into the chart area below.
        final isEnd = verticalAlign == HeroAlign.end;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment:
                isEnd ? MainAxisAlignment.end : MainAxisAlignment.center,
            // MainAxisSize.min in the center case keeps the legacy phone
            // portrait shrink-to-fit behaviour; for end alignment the column
            // must fill its slot so the children can sit against the bottom.
            mainAxisSize: isEnd ? MainAxisSize.max : MainAxisSize.min,
            children: [
              paceDisplay(),
              if (!isCountingDown) ...[
                const SizedBox(height: 8),
                strokeRateDisplay(),
              ],
              if (guide != null) ...[
                const SizedBox(height: 10),
                guide,
              ],
              if (anim != null) ...[
                const SizedBox(height: 8),
                anim,
              ],
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
