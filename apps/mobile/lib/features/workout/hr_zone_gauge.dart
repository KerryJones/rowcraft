import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../app/theme.dart';

/// Garmin-style HR zone arc gauge using Syncfusion SfRadialGauge.
///
/// Renders a 270° arc with 5 colored zone segments. The active zone is fully
/// opaque and thicker; inactive zones are dimmed. A circle marker shows the
/// exact BPM position. The BPM value, zone name, and a heart icon are
/// centered inside the arc.
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

  @override
  Widget build(BuildContext context) {
    final zone = estimateHrZone(bpm, maxHr: maxHr);
    final info = hrZoneInfo(zone);
    final maxValue = maxHr * 1.05;
    final clampedBpm = bpm.toDouble().clamp(0.0, maxValue);

    // Zone boundary values in BPM
    final zoneBounds = [
      0.0,
      maxHr * 0.6,
      maxHr * 0.7,
      maxHr * 0.8,
      maxHr * 0.9,
      maxValue,
    ];

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
                maximum: maxValue,
                showLabels: false,
                showTicks: false,
                showAxisLine: false,
                radiusFactor: 0.85,
                canScaleToFit: false,
                ranges: <GaugeRange>[
                  for (var i = 0; i < 5; i++)
                    GaugeRange(
                      startValue: zoneBounds[i],
                      endValue: zoneBounds[i + 1],
                      color: (zone - 1) == i
                          ? _zoneColors[i]
                          : _zoneColors[i].withValues(alpha: 0.25),
                      startWidth: (zone - 1) == i ? 18 : 14,
                      endWidth: (zone - 1) == i ? 18 : 14,
                    ),
                ],
                pointers: <GaugePointer>[
                  MarkerPointer(
                    value: clampedBpm,
                    markerType: MarkerType.circle,
                    markerHeight: 16,
                    markerWidth: 16,
                    color: info.color,
                    borderColor: Colors.white,
                    borderWidth: 3,
                    enableAnimation: bpm > 0,
                    animationDuration: 300,
                    animationType: AnimationType.ease,
                  ),
                ],
                annotations: <GaugeAnnotation>[
                  GaugeAnnotation(
                    angle: 90,
                    positionFactor: 0,
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          info.label,
                          style: GoogleFonts.inter(
                            fontSize: size * 0.075,
                            fontWeight: FontWeight.w600,
                            color: info.color,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          '$bpm',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: size * 0.22,
                            fontWeight: FontWeight.w700,
                            color: info.color,
                            height: 1.1,
                          ),
                        ),
                        Icon(
                          Icons.favorite,
                          size: size * 0.09,
                          color: info.color,
                        ),
                      ],
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
