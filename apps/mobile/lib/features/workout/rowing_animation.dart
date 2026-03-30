import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Animated rowing figure that visually communicates stroke tempo.
///
/// The stick figure cycles through catch → drive → finish → recovery
/// at a speed matching the current [strokeRate] (strokes per minute).
/// When [strokeRate] is 0, the figure sits still at the catch position.
class RowingAnimation extends StatefulWidget {
  final int strokeRate;
  final bool isActive;
  final double height;

  const RowingAnimation({
    super.key,
    required this.strokeRate,
    this.isActive = false,
    this.height = 48,
  });

  @override
  State<RowingAnimation> createState() => _RowingAnimationState();
}

class _RowingAnimationState extends State<RowingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _updateAnimation();
  }

  @override
  void didUpdateWidget(RowingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.strokeRate != widget.strokeRate ||
        oldWidget.isActive != widget.isActive) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.strokeRate <= 0 || !widget.isActive) {
      _controller.stop();
      _controller.value = 0.0; // Catch position
      return;
    }

    // One full stroke cycle duration based on stroke rate
    // At 24 s/m → 2500ms, at 30 s/m → 2000ms, at 36 s/m → 1667ms
    final cycleDuration = Duration(
      milliseconds: (60000 / widget.strokeRate).round(),
    );

    _controller.duration = cycleDuration;
    // Stop and restart to pick up new duration; preserve progress for
    // a seamless transition between stroke rates.
    final currentValue = _controller.value;
    _controller.stop();
    _controller.value = currentValue;
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.height * 2.0; // 2:1 aspect ratio

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(width, widget.height),
          painter: _RowerPainter(
            progress: _controller.value,
            color: widget.isActive
                ? RowCraftTheme.primaryBlue
                : RowCraftTheme.subtleGrey,
          ),
        );
      },
    );
  }
}

/// Paints a stick-figure rower at a given [progress] through the stroke cycle.
///
/// Progress 0.0-0.25: Catch → Drive (legs push, body swings back)
/// Progress 0.25-0.5: Drive → Finish (arms pull to chest)
/// Progress 0.5-0.75: Finish → Recovery (arms extend forward)
/// Progress 0.75-1.0: Recovery → Catch (body rocks over, legs slide forward)
class _RowerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RowerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Coordinate system: origin at center, normalized to size
    final h = size.height;
    final w = size.width;

    // Rail (seat track) — thin horizontal line at bottom
    final railY = h * 0.82;
    final railPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.15, railY),
      Offset(w * 0.85, railY),
      railPaint,
    );

    // Interpolate body positions based on stroke phase
    final pose = _interpolatePose(progress);

    // Seat position on rail
    final seatX = w * pose.seatX;
    final seatY = railY - 2;

    // Hip (on the seat)
    final hipX = seatX;
    final hipY = seatY - h * 0.08;

    // Shoulder position (body angle from hip)
    final shoulderX = hipX + cos(pose.bodyAngle) * h * 0.32;
    final shoulderY = hipY - sin(pose.bodyAngle) * h * 0.32;

    // Head
    final headX = shoulderX + cos(pose.bodyAngle) * h * 0.08;
    final headY = shoulderY - sin(pose.bodyAngle) * h * 0.08;
    final headRadius = h * 0.07;

    // Feet position (fixed at footplate)
    final footX = w * 0.28;
    final footY = railY - 1;

    // Knee (calculated from hip and foot positions)
    final kneeX = (hipX + footX) / 2 + (hipX - footX).abs() * 0.1;
    final kneeY = hipY - h * 0.15 * (1.0 - pose.legBend);

    // Hand position (on the handle)
    final handleX = hipX + cos(pose.bodyAngle) * h * pose.armExtension;
    final handleY = hipY - h * 0.12;

    // Elbow
    final elbowX = (shoulderX + handleX) / 2;
    final elbowY = shoulderY + h * 0.05;

    // Draw body parts

    // Legs (hip → knee → foot)
    canvas.drawLine(Offset(hipX, hipY), Offset(kneeX, kneeY), paint);
    canvas.drawLine(Offset(kneeX, kneeY), Offset(footX, footY), paint);

    // Body (hip → shoulder)
    canvas.drawLine(Offset(hipX, hipY), Offset(shoulderX, shoulderY), paint);

    // Arms (shoulder → elbow → hand)
    canvas.drawLine(
        Offset(shoulderX, shoulderY), Offset(elbowX, elbowY), paint);
    canvas.drawLine(Offset(elbowX, elbowY), Offset(handleX, handleY), paint);

    // Handle (small horizontal bar at hand position)
    canvas.drawLine(
      Offset(handleX - 3, handleY),
      Offset(handleX + 3, handleY),
      Paint()
        ..color = color
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // Head
    canvas.drawCircle(Offset(headX, headY), headRadius, fillPaint);

    // Seat (small rectangle on rail)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(seatX, seatY), width: 8, height: 4),
        const Radius.circular(2),
      ),
      fillPaint,
    );
  }

  /// Interpolate between the 4 key rowing positions based on progress.
  _RowingPose _interpolatePose(double p) {
    // Key poses:
    // Catch (p=0.0):    seat forward, body leaned forward, arms extended
    // Drive (p=0.25):   seat back, body upright, arms still extended
    // Finish (p=0.5):   seat back, body leaned back slightly, arms pulled in
    // Recovery (p=0.75): seat back, body rocking forward, arms extending
    // Back to Catch (p=1.0)

    const catch_ = _RowingPose(
      seatX: 0.35,
      bodyAngle: 1.2, // ~70° forward lean
      armExtension: 0.6,
      legBend: 0.9,
    );
    const drive = _RowingPose(
      seatX: 0.60,
      bodyAngle: 1.5, // ~85° near upright
      armExtension: 0.55,
      legBend: 0.3,
    );
    const finish = _RowingPose(
      seatX: 0.65,
      bodyAngle: 1.8, // ~103° slight lean back
      armExtension: 0.15,
      legBend: 0.1,
    );
    const recovery = _RowingPose(
      seatX: 0.50,
      bodyAngle: 1.3,
      armExtension: 0.5,
      legBend: 0.5,
    );

    if (p < 0.25) {
      return _RowingPose.lerp(catch_, drive, p / 0.25);
    } else if (p < 0.5) {
      return _RowingPose.lerp(drive, finish, (p - 0.25) / 0.25);
    } else if (p < 0.75) {
      return _RowingPose.lerp(finish, recovery, (p - 0.5) / 0.25);
    } else {
      return _RowingPose.lerp(recovery, catch_, (p - 0.75) / 0.25);
    }
  }

  @override
  bool shouldRepaint(covariant _RowerPainter oldDelegate) {
    return progress != oldDelegate.progress || color != oldDelegate.color;
  }
}

/// Describes a single pose of the rowing figure.
class _RowingPose {
  /// Seat position along the rail (0.0 = left/front, 1.0 = right/back)
  final double seatX;

  /// Body angle in radians (higher = more upright/leaned back)
  final double bodyAngle;

  /// How far arms are extended (0.0 = pulled in, 1.0 = fully extended)
  final double armExtension;

  /// How bent the legs are (0.0 = straight, 1.0 = fully compressed)
  final double legBend;

  const _RowingPose({
    required this.seatX,
    required this.bodyAngle,
    required this.armExtension,
    required this.legBend,
  });

  static _RowingPose lerp(_RowingPose a, _RowingPose b, double t) {
    return _RowingPose(
      seatX: a.seatX + (b.seatX - a.seatX) * t,
      bodyAngle: a.bodyAngle + (b.bodyAngle - a.bodyAngle) * t,
      armExtension: a.armExtension + (b.armExtension - a.armExtension) * t,
      legBend: a.legBend + (b.legBend - a.legBend) * t,
    );
  }
}
