import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

/// Garmin-style HR zone arc gauge with 5 colored bands.
///
/// Renders a 270° arc with thick zone segments. The active zone is fully
/// opaque and slightly thicker; inactive zones are dimmed. A white marker
/// dot shows the exact BPM position. The BPM value, zone name, and a
/// heart icon are centered inside the arc.
class HrZoneGauge extends StatelessWidget {
  final int bpm;
  final int maxHr;

  const HrZoneGauge({
    super.key,
    required this.bpm,
    this.maxHr = 190,
  });

  @override
  Widget build(BuildContext context) {
    final zone = estimateHrZone(bpm, maxHr: maxHr);
    final info = hrZoneInfo(zone);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Arc gauge
              CustomPaint(
                painter: _HrZoneArcPainter(bpm: bpm, maxHr: maxHr),
                size: Size(size, size),
              ),
              // Center content: zone label + BPM + heart
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zone label
                  Text(
                    info.label,
                    style: GoogleFonts.inter(
                      fontSize: size * 0.075,
                      fontWeight: FontWeight.w600,
                      color: info.color,
                      letterSpacing: 1.0,
                    ),
                  ),
                  // BPM number
                  Text(
                    '$bpm',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.w700,
                      color: info.color,
                      height: 1.1,
                    ),
                  ),
                  // Heart icon
                  Icon(
                    Icons.favorite,
                    size: size * 0.09,
                    color: info.color,
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

class _HrZoneArcPainter extends CustomPainter {
  final int bpm;
  final int maxHr;

  _HrZoneArcPainter({required this.bpm, required this.maxHr});

  // Zone boundaries as fractions of max HR
  static const _zoneFractions = [0.0, 0.6, 0.7, 0.8, 0.9, 1.05];
  static const _zoneColors = [
    RowCraftTheme.hrZone1,
    RowCraftTheme.hrZone2,
    RowCraftTheme.hrZone3,
    RowCraftTheme.hrZone4,
    RowCraftTheme.hrZone5,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.85;
    const baseStroke = 14.0;
    const activeStroke = 18.0;
    const gapAngle = 0.025;

    // 270° arc: starts at 135° (bottom-left), sweeps clockwise to 45° (bottom-right)
    const startAngle = 135.0 * pi / 180; // 135°
    const totalSweep = 270.0 * pi / 180; // 270°

    final totalRange = _zoneFractions.last - _zoneFractions.first;
    final currentFraction = (bpm / maxHr).clamp(0.0, 1.05);
    final currentZone = _zoneForFraction(currentFraction);

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Draw zone segments
    for (var i = 0; i < 5; i++) {
      final zoneStart = _zoneFractions[i];
      final zoneEnd = _zoneFractions[i + 1];
      final isActive = i == currentZone;

      final segStart = startAngle +
          totalSweep * (zoneStart / totalRange) +
          (i == 0 ? 0 : gapAngle / 2);
      final segEnd = startAngle + totalSweep * (zoneEnd / totalRange);
      final segSweep = segEnd - segStart - (i == 4 ? 0 : gapAngle / 2);

      final paint = Paint()
        ..color = isActive
            ? _zoneColors[i]
            : _zoneColors[i].withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? activeStroke : baseStroke
        ..strokeCap = i == 0 || i == 4 ? StrokeCap.round : StrokeCap.butt;

      canvas.drawArc(arcRect, segStart, segSweep, false, paint);
    }

    // Draw position marker (white dot with colored center)
    final markerFraction = currentFraction.clamp(0.0, 1.0);
    final markerAngle =
        startAngle + totalSweep * (markerFraction / totalRange);
    final markerX = center.dx + radius * cos(markerAngle);
    final markerY = center.dy + radius * sin(markerAngle);

    // White outer circle
    canvas.drawCircle(
      Offset(markerX, markerY),
      activeStroke / 2 + 2,
      Paint()..color = Colors.white,
    );
    // Colored inner
    canvas.drawCircle(
      Offset(markerX, markerY),
      activeStroke / 2 - 1,
      Paint()..color = _zoneColors[currentZone],
    );
  }

  int _zoneForFraction(double fraction) {
    if (fraction < _zoneFractions[1]) return 0;
    if (fraction < _zoneFractions[2]) return 1;
    if (fraction < _zoneFractions[3]) return 2;
    if (fraction < _zoneFractions[4]) return 3;
    return 4;
  }

  @override
  bool shouldRepaint(_HrZoneArcPainter old) =>
      old.bpm != bpm || old.maxHr != maxHr;
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
