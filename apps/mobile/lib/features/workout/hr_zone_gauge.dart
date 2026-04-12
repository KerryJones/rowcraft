import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../app/theme.dart';

/// Garmin-style HR zone arc gauge using Syncfusion SfRadialGauge.
///
/// Renders a 270° arc with 5 equally-sized colored zone segments. The active
/// zone is fully opaque and thicker; inactive zones are dimmed. A thin white
/// rectangle tick shows the exact BPM position within its zone. The BPM value
/// is centered inside the arc in the active zone's color.
class HrZoneGauge extends StatelessWidget {
  final int bpm;
  final int maxHr;

  const HrZoneGauge({
    super.key,
    required this.bpm,
    this.maxHr = 190,
  });

  static const _zoneColors = [
    RowCraftTheme.hrZone1,
    RowCraftTheme.hrZone2,
    RowCraftTheme.hrZone3,
    RowCraftTheme.hrZone4,
    RowCraftTheme.hrZone5,
  ];

  // Zone boundaries as fractions of max HR.
  static const _zoneFractions = [0.0, 0.6, 0.7, 0.8, 0.9, 1.05];

  // Small inset between adjacent zones to create visible gaps.
  static const _gap = 0.04;

  /// Maps a real BPM value into the abstract 0–5 gauge scale where each
  /// integer boundary represents a zone transition. Within each zone, the
  /// position is linearly interpolated based on where the BPM falls in that
  /// zone's real HR range. The returned value is clamped to the rendered
  /// segment bounds so the marker never lands in a gap.
  static double _bpmToGaugeValue(int bpmVal, int maxHrVal) {
    if (maxHrVal <= 0 || bpmVal <= 0) return 0.0;

    // Use rounded BPM boundaries to match estimateHrZone().
    final zoneBpm = [
      0.0,
      for (var f in _zoneFractions.skip(1).take(4))
        (maxHrVal * f).roundToDouble(),
      maxHrVal * _zoneFractions[5],
    ];

    final bpm = bpmVal.toDouble();
    if (bpm >= zoneBpm[5]) return 5.0;

    for (var i = 0; i < 5; i++) {
      if (bpm < zoneBpm[i + 1]) {
        final range = zoneBpm[i + 1] - zoneBpm[i];
        final fraction = range > 0 ? (bpm - zoneBpm[i]) / range : 0.0;
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
    final zone = estimateHrZone(bpm, maxHr: maxHr);
    final info = hrZoneInfo(zone);
    final displayColor = hasHr ? info.color : RowCraftTheme.subtleGrey;
    final gaugeValue = _bpmToGaugeValue(bpm, maxHr);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);

        return SizedBox(
          width: size,
          height: size,
          child: SfRadialGauge(
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
                canScaleToFit: false,
                ranges: <GaugeRange>[
                  for (var i = 0; i < 5; i++)
                    GaugeRange(
                      startValue: i + (i == 0 ? 0 : _gap),
                      endValue: (i + 1) - (i == 4 ? 0 : _gap),
                      color: hasHr && (zone - 1) == i
                          ? _zoneColors[i]
                          : _zoneColors[i].withValues(alpha: 0.25),
                      startWidth: hasHr && (zone - 1) == i ? 18 : 14,
                      endWidth: hasHr && (zone - 1) == i ? 18 : 14,
                    ),
                ],
                pointers: <GaugePointer>[
                  if (hasHr)
                    MarkerPointer(
                      value: gaugeValue,
                      markerType: MarkerType.rectangle,
                      markerHeight: 22,
                      markerWidth: 3,
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
          ),
        );
      },
    );
  }
}

/// HR zone estimate from BPM using percentage of max heart rate.
int estimateHrZone(int bpm, {int maxHr = 190}) {
  if (bpm < (maxHr * 0.6).round()) return 1;
  if (bpm < (maxHr * 0.7).round()) return 2;
  if (bpm < (maxHr * 0.8).round()) return 3;
  if (bpm < (maxHr * 0.9).round()) return 4;
  return 5;
}

/// HR zone info: name, label, color.
({String name, String label, Color color}) hrZoneInfo(int zone) {
  return switch (zone) {
    1 => (name: 'ZONE 1', label: 'RECOVERY', color: RowCraftTheme.hrZone1),
    2 => (name: 'ZONE 2', label: 'ENDURANCE', color: RowCraftTheme.hrZone2),
    3 => (name: 'ZONE 3', label: 'TEMPO', color: RowCraftTheme.hrZone3),
    4 => (name: 'ZONE 4', label: 'THRESHOLD', color: RowCraftTheme.hrZone4),
    5 => (name: 'ZONE 5', label: 'VO2 MAX', color: RowCraftTheme.hrZone5),
    _ => (name: 'ZONE ?', label: '', color: RowCraftTheme.subtleGrey),
  };
}
