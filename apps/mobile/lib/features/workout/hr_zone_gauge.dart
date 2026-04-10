import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Garmin Edge-style HR zone arc gauge.
///
/// Draws a 180° arc with 5 colored zone segments and a position marker
/// showing current BPM. The BPM number is displayed large in the center.
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
    return CustomPaint(
      painter: _HrZoneArcPainter(bpm: bpm, maxHr: maxHr),
      child: const SizedBox.expand(),
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
    final centerX = size.width / 2;
    final centerY = size.height * 0.75;
    final radius = min(centerX, centerY) * 0.85;
    const strokeWidth = 8.0;
    const gapAngle = 0.02; // Small gap between segments

    // Arc sweeps from π (left) to 0 (right) = 180° total
    const startAngle = pi; // left side
    const totalSweep = pi; // 180 degrees

    final arcRect = Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: radius,
    );

    // Draw zone segments
    for (var i = 0; i < 5; i++) {
      final zoneStart = _zoneFractions[i];
      final zoneEnd = _zoneFractions[i + 1];
      final totalRange = _zoneFractions[5] - _zoneFractions[0];
      final segStart =
          startAngle + totalSweep * (zoneStart / totalRange) + gapAngle;
      final segSweep =
          totalSweep * ((zoneEnd - zoneStart) / totalRange) - gapAngle * 2;

      canvas.drawArc(
        arcRect,
        segStart,
        segSweep,
        false,
        Paint()
          ..color = _zoneColors[i].withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Draw position marker. Clamp to 1.0 (not _zoneFractions[5]=1.05) so the
    // marker reaches the arc end at exactly maxHr — zone segments extend to
    // 1.05 for visual fill but the marker position uses the same 0..1 range.
    final fraction = (bpm / maxHr).clamp(0.0, 1.0);
    final totalRange = _zoneFractions[5] - _zoneFractions[0];
    final markerAngle =
        startAngle + totalSweep * (fraction / totalRange);
    final markerX = centerX + radius * cos(markerAngle);
    final markerY = centerY + radius * sin(markerAngle);

    // Determine current zone color
    final zoneColor = _colorForBpm(bpm);

    // Bright arc segment around current position
    const markerSweep = totalSweep * 0.04;
    canvas.drawArc(
      arcRect,
      markerAngle - markerSweep / 2,
      markerSweep,
      false,
      Paint()
        ..color = zoneColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 3
        ..strokeCap = StrokeCap.round,
    );

    // Marker dot
    canvas.drawCircle(
      Offset(markerX, markerY),
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(markerX, markerY),
      3,
      Paint()..color = zoneColor,
    );
  }

  Color _colorForBpm(int bpm) {
    final pct = bpm / maxHr;
    if (pct < 0.6) return _zoneColors[0];
    if (pct < 0.7) return _zoneColors[1];
    if (pct < 0.8) return _zoneColors[2];
    if (pct < 0.9) return _zoneColors[3];
    return _zoneColors[4];
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
