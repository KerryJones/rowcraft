import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Animated rowing indicator — EXR-inspired simple visualization.
///
/// Shows a horizontal rail with a circle (rower) sliding back and forth,
/// and a short handle bar that moves with the stroke. Speed matches
/// the current [strokeRate] (strokes per minute).
/// When [strokeRate] is 0, the indicator sits still at the catch position.
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
      _controller.value = 0.0;
      return;
    }

    final cycleDuration = Duration(
      milliseconds: (60000 / widget.strokeRate).round(),
    );

    _controller.duration = cycleDuration;
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
    final width = widget.height * 2.5;
    final color = widget.isActive
        ? RowCraftTheme.primaryBlue
        : RowCraftTheme.subtleGrey;

    return SizedBox(
      width: width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Convert 0→1 controller value to back-and-forth motion:
          // 0.0→0.4 = drive (catch to finish, fast)
          // 0.4→1.0 = recovery (finish to catch, slower)
          final p = _controller.value;
          double slideProgress;
          if (p < 0.4) {
            // Drive phase: seat moves right (0 → 1)
            slideProgress = p / 0.4;
          } else {
            // Recovery phase: seat moves left (1 → 0)
            slideProgress = 1.0 - ((p - 0.4) / 0.6);
          }

          // Rail dimensions
          final railLeft = width * 0.05;
          final railRight = width * 0.95;
          final railWidth = railRight - railLeft;
          final centerY = widget.height * 0.55;

          // Rower circle position along rail
          final circleX = railLeft + slideProgress * railWidth;
          final circleRadius = widget.height * 0.16;

          // Handle position (leads the circle during drive, trails during recovery)
          final handleOffset = widget.height * 0.35;
          final handleX = circleX - handleOffset;
          final handleHalfHeight = widget.height * 0.12;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Rail line
              Positioned(
                left: railLeft,
                top: centerY - 1,
                child: Container(
                  width: railWidth,
                  height: 2,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              // Handle bar (short vertical line)
              Positioned(
                left: handleX.clamp(railLeft, railRight) - 1.5,
                top: centerY - handleHalfHeight,
                child: Container(
                  width: 3,
                  height: handleHalfHeight * 2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              // Rower circle
              Positioned(
                left: circleX - circleRadius,
                top: centerY - circleRadius - widget.height * 0.1,
                child: Container(
                  width: circleRadius * 2,
                  height: circleRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
