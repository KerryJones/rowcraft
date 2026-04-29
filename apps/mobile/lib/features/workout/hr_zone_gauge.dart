import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../app/theme.dart';
import '../../utils/hr_zones.dart';

/// Garmin-style HR zone arc gauge using Syncfusion SfRadialGauge.
///
/// Renders a 270 degree arc with 5 colored zone segments. The active
/// zone is fully opaque and thicker; inactive zones are dimmed. A short white
/// radial bar shows the exact BPM position on the arc. The BPM value is
/// centered inside the arc in the active zone's color.
class HrZoneGauge extends StatelessWidget {
  final int bpm;
  final int maxHr;
  final int? restingHr;
  final ZoneSystem zoneSystem;

  const HrZoneGauge({
    super.key,
    required this.bpm,
    this.maxHr = 190,
    this.restingHr,
    this.zoneSystem = ZoneSystem.rowing,
  });

  static const _zoneColors = [
    RowCraftTheme.hrZone1,
    RowCraftTheme.hrZone2,
    RowCraftTheme.hrZone3,
    RowCraftTheme.hrZone4,
    RowCraftTheme.hrZone5,
  ];

  // Zone boundaries as fractions of HRR (or HRmax when no resting HR).
  // 55% / 75% / 85% / 92% / 97% / 105% (overMax for gauge headroom)
  static const _zoneFractions = [0.55, 0.75, 0.85, 0.92, 0.97, 1.05];

  // Small inset between adjacent zones to create visible gaps.
  static const _gap = 0.04;

  /// Maps a real BPM value into the abstract 0-5 gauge scale where each
  /// integer boundary represents a zone transition. Within each zone, the
  /// position is linearly interpolated based on where the BPM falls in that
  /// zone's real HR range. The returned value is clamped to the rendered
  /// segment bounds so the marker never lands in a gap.
  double _bpmToGaugeValue(int bpmVal) {
    if (maxHr <= 0 || bpmVal <= 0) return 0.0;

    // Convert BPM to a 0.0–1.0 fraction of HRR (or HRmax when no resting HR).
    // Note: _zoneFractions are also 0.0–1.0 fractions, NOT 0–100 percentages.
    double frac;
    if (restingHr != null && maxHr > restingHr!) {
      frac = (bpmVal - restingHr!) / (maxHr - restingHr!);
    } else {
      frac = bpmVal / maxHr;
    }

    if (frac >= _zoneFractions[5]) return 5.0;

    // Below zone 1 — clamp to start
    if (frac < _zoneFractions[0]) return 0.0;

    for (var i = 0; i < 5; i++) {
      if (frac < _zoneFractions[i + 1]) {
        final range = _zoneFractions[i + 1] - _zoneFractions[i];
        final fraction = range > 0 ? (frac - _zoneFractions[i]) / range : 0.0;
        final raw = i + fraction.clamp(0.0, 1.0);
        // Clamp to rendered segment bounds so marker stays on the arc
        final segStart = i + (i == 0 ? 0.0 : _gap);
        final segEnd = (i + 1) - (i == 4 ? 0.0 : _gap);
        return raw.clamp(segStart, segEnd);
      }
    }
    return 5.0;
  }

  @override
  Widget build(BuildContext context) {
    final hasHr = bpm > 0;
    final zone = estimateHrZone(bpm, maxHr, restingHr: restingHr);
    final info = zoneDisplayInfo(zone, zoneSystem);
    final displayColor = hasHr ? info.color : RowCraftTheme.subtleGrey;
    final gaugeValue = _bpmToGaugeValue(bpm);

    // Zone 0 (below zone) doesn't have an arc — treat as zone 1 for dimming
    final activeArc = zone > 0 ? zone - 1 : -1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);

        return SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                startAngle: 135,
                endAngle: 45,
                minimum: 0,
                maximum: 5,
                showLabels: false,
                showTicks: false,
                showAxisLine: false,
                radiusFactor: 0.95,
                canScaleToFit: true,
                ranges: <GaugeRange>[
                  for (var i = 0; i < 5; i++)
                    GaugeRange(
                      startValue: i + (i == 0 ? 0 : _gap),
                      endValue: (i + 1) - (i == 4 ? 0 : _gap),
                      color: hasHr && activeArc == i
                          ? _zoneColors[i]
                          : _zoneColors[i].withValues(alpha: 0.25),
                      startWidth: hasHr && activeArc == i ? 18 : 14,
                      endWidth: hasHr && activeArc == i ? 18 : 14,
                    ),
                ],
                pointers: <GaugePointer>[
                  if (hasHr)
                    MarkerPointer(
                      value: gaugeValue,
                      markerType: MarkerType.rectangle,
                      markerHeight: 2,
                      markerWidth: 22,
                      markerOffset: 3,
                      color: Colors.white,
                      enableAnimation: true,
                      animationDuration: 300,
                      animationType: AnimationType.ease,
                    ),
                ],
                annotations: <GaugeAnnotation>[
                  GaugeAnnotation(
                    angle: 90,
                    positionFactor: 0,
                    widget: Text(
                      hasHr ? '$bpm' : '--',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: size * 0.26,
                        fontWeight: FontWeight.w700,
                        color: displayColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
      },
    );
  }
}
