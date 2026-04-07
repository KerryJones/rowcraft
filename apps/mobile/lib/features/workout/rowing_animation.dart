import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

// ════════════════════════════════════════════════════════════════════════════
//  ERG ROWING ANIMATION — Stick-figure rower with sequential muscle activation
//
//  Architecture:
//    1. Virtual coordinate system (600×300) scaled to fit any widget size
//    2. Phase timing: legs → body → arms drive, then reverse on recovery
//    3. 2-link IK for legs (knee bends UP) and arms (elbow bends DOWN)
//    4. Single smooth handle trajectory across entire drive (no phase jerk)
//    5. Muscle color fades in/out per phase via Color.lerp
//
//  All tunable values are in the CONFIG sections below.
// ════════════════════════════════════════════════════════════════════════════

// ── COLORS (dark theme) ─────────────────────────────────────────────────────
const _colorActive = RowCraftTheme.errorRose; // muscle highlight — red
const _colorRest = RowCraftTheme.metricWhite; // body at rest — light
const _colorHandle = RowCraftTheme.segmentWork; // handle/chain — blue
const _colorInactive = RowCraftTheme.subtleGrey; // everything when not rowing
const _colorErg = RowCraftTheme.subtleGrey; // rail, seat

// ── STROKE WIDTHS (virtual coordinate px) ───────────────────────────────────
const _strokeLegs = 5.0;
const _strokeTorso = 5.0;
const _strokeNeck = 4.0;
const _strokeArms = 4.0;
const _strokeRail = 2.5;

// ── BODY SEGMENT LENGTHS (virtual px) ───────────────────────────────────────
const _shinLen = 60.0; // ankle → knee
const _thighLen = 80.0; // knee → hip
const _torsoLen = 88.0; // hip → shoulder
const _neckLen = 10.0; // shoulder → base of head
const _headR = 12.0; // head circle radius
const _uArmLen = 42.0; // shoulder → elbow
const _fArmLen = 46.0; // elbow → handle

// ── SEAT / HANDLE GEOMETRY ──────────────────────────────────────────────────
const _seatW = 22.0;
const _seatH = 5.0;
const _handleR = 12.0;
const _handleY = 157.0; // fixed Y for handle throughout stroke
const _armPullDist = 22.0; // how far in front of shoulder handle stops

// ── LAYOUT (vertical layers in virtual coords) ──────────────────────────────
const _railY = 242.0;
const _seatY = 233.0;
const _legY = 226.0;
const _ankleX = 185.0;

// ── TORSO ANGLES (degrees from vertical) ────────────────────────────────────
const _angleCatch = -18.0; // forward lean at catch
const _angleFinish = 22.0; // layback at finish

// ── STROKE TIMING (fraction of full cycle 0..1) ────────────────────────────
const _driveEnd = 0.38;
const _pauseEnd = 0.50;
const _legPhaseEnd = 0.55; // within drive
const _bodyPhaseStart = 0.35;
const _bodyPhaseEnd = 0.75;
const _armPhaseStart = 0.72;

// ── RECOVERY TIMING (fraction of recovery phase 0..1) ───────────────────────
const _recovArmEnd = 0.18; // arms extend out
const _recovBodyHold = 0.12; // body holds finish layback
const _recovBodyEnd = 0.45; // body swing forward complete
const _recovLegStart = 0.35; // legs begin compressing

// ── VIEWPORT (crops the 600×300 virtual canvas to the figure bounds) ────────
// All geometry uses the original 600×300 coordinate system. The viewport
// controls which region is scaled to fill the widget, removing dead space.
const _viewLeft = 90.0;
const _viewTop = 100.0;
const _viewRight = 510.0;
const _viewBottom = 255.0;
const _viewWidth = _viewRight - _viewLeft; // 420
const _viewHeight = _viewBottom - _viewTop; // 155

// ── DERIVED CONSTANTS ───────────────────────────────────────────────────────
const _armTotal = _uArmLen + _fArmLen;
final _hipCatch =
    _ankleX + sqrt(max(0, _thighLen * _thighLen - _shinLen * _shinLen));
const _hipExt = _ankleX + _shinLen + _thighLen;

final _catchHandX = () {
  final sx =
      _hipCatch + _torsoLen * sin(_angleCatch * pi / 180);
  final sy = _legY - _torsoLen * cos(_angleCatch * pi / 180);
  final dy = _handleY - sy;
  return sx - sqrt(max(0, _armTotal * _armTotal - dy * dy));
}();

final _finishHandX =
    _hipExt + _torsoLen * sin(_angleFinish * pi / 180) - _armPullDist;

// ── UTILITY FUNCTIONS ───────────────────────────────────────────────────────
double _ease(double t) {
  t = t.clamp(0.0, 1.0);
  return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
}
double _lerp(double a, double b, double t) => a + (b - a) * t;
Color _lerpColor(Color c1, Color c2, double t) =>
    Color.lerp(c1, c2, t.clamp(0, 1))!;

// ── PHASE DATA ──────────────────────────────────────────────────────────────
class _Phases {
  final double legPos;
  final double bodyAng;
  final double armBend;
  final bool inDrive;
  final double driveP;

  const _Phases({
    required this.legPos,
    required this.bodyAng,
    required this.armBend,
    required this.inDrive,
    required this.driveP,
  });
}

_Phases _getPhases(double gt) {
  gt = gt % 1.0;
  final inDrive = gt < _driveEnd;
  final inPause = gt >= _driveEnd && gt < _pauseEnd;
  double legPos, bodyAng, armBend;

  if (inDrive) {
    final d = gt / _driveEnd;
    legPos = d < _legPhaseEnd ? _ease(d / _legPhaseEnd) : 1.0;
    bodyAng = d < _bodyPhaseStart
        ? 0.0
        : d < _bodyPhaseEnd
            ? _ease((d - _bodyPhaseStart) / (_bodyPhaseEnd - _bodyPhaseStart))
            : 1.0;
    armBend = d < _armPhaseStart
        ? 0.0
        : _ease((d - _armPhaseStart) / (1.0 - _armPhaseStart));
  } else if (inPause) {
    legPos = 1.0;
    bodyAng = 1.0;
    armBend = 1.0;
  } else {
    final r = (gt - _pauseEnd) / (1.0 - _pauseEnd);
    armBend = r < _recovArmEnd ? 1.0 - _ease(r / _recovArmEnd) : 0.0;
    bodyAng = r < _recovBodyHold
        ? 1.0
        : r < _recovBodyEnd
            ? 1.0 -
                _ease(
                    (r - _recovBodyHold) / (_recovBodyEnd - _recovBodyHold))
            : 0.0;
    legPos = r < _recovLegStart
        ? 1.0
        : 1.0 - _ease((r - _recovLegStart) / (1.0 - _recovLegStart));
  }

  return _Phases(
    legPos: legPos,
    bodyAng: bodyAng,
    armBend: armBend,
    inDrive: inDrive,
    driveP: inDrive ? gt / _driveEnd : inPause ? 1.0 : 0.0,
  );
}

// ── POSE DATA ───────────────────────────────────────────────────────────────
class _Pose {
  final Offset ankle;
  final Offset knee;
  final Offset hip;
  final Offset shoulder;
  final Offset neckTop;
  final Offset elbow;
  final Offset hand;
  final Offset head;
  final double seatX;
  final Color legColor;
  final Color torsoColor;
  final Color armColor;

  const _Pose({
    required this.ankle,
    required this.knee,
    required this.hip,
    required this.shoulder,
    required this.neckTop,
    required this.elbow,
    required this.hand,
    required this.head,
    required this.seatX,
    required this.legColor,
    required this.torsoColor,
    required this.armColor,
  });
}

_Pose _computePose(double t, bool isActive) {
  final gt = t % 1.0;
  final ph = _getPhases(gt);

  // ── Hip (on seat, determined by leg extension) ──
  final hipX = _hipCatch + ph.legPos * (_hipExt - _hipCatch);
  const hipY = _legY;

  // ── Legs: IK from fixed ankle to hip, knee bends UP ──
  const ankleX = _ankleX;
  const ankleY = _legY;
  final dx = hipX - ankleX;
  const dy = 0.0; // both at _legY
  final dist =
      sqrt(dx * dx + dy * dy).clamp(1.0, _shinLen + _thighLen - 0.5);
  final baseAng = atan2(dy, dx);

  final cosA = ((_shinLen * _shinLen + dist * dist - _thighLen * _thighLen) /
          (2 * _shinLen * dist))
      .clamp(-1.0, 1.0);
  final offA = acos(cosA);

  // IK knee (up)
  final ikKneeX = ankleX + _shinLen * cos(baseAng - offA);
  final ikKneeY = ankleY + _shinLen * sin(baseAng - offA);

  // Straight-line knee (on ankle→hip line)
  const lineFrac = _shinLen / (_shinLen + _thighLen);
  final lineKneeX = _lerp(ankleX, hipX, lineFrac);
  const lineKneeY = _legY;

  // Blend: knee melts into straight line as legs extend
  final straightBlend = _ease((ph.legPos - 0.60).clamp(0, 1) / 0.40);
  final kneeX = _lerp(ikKneeX, lineKneeX, straightBlend);
  final kneeY = _lerp(ikKneeY, lineKneeY, straightBlend);

  // ── Seat follows hip ──
  final seatX = hipX - _seatW / 2;

  // ── Torso ──
  final tDeg = _lerp(_angleCatch, _angleFinish, ph.bodyAng);
  final tRad = tDeg * pi / 180;
  final shoulderX = hipX + _torsoLen * sin(tRad);
  final shoulderY = hipY - _torsoLen * cos(tRad);

  // ── Neck ──
  final neckTopX = shoulderX + _neckLen * sin(tRad);
  final neckTopY = shoulderY - _neckLen * cos(tRad);

  // ── Head ──
  final headX = neckTopX + _headR * sin(tRad);
  final headY = neckTopY - _headR * cos(tRad);

  // ── Arms: smooth handle trajectory ──
  final inPauseA = gt >= _driveEnd && gt < _pauseEnd;
  // Straight-arm handle position from this shoulder
  final armDy = _handleY - shoulderY;
  final armDxStraight =
      sqrt(max(0, _armTotal * _armTotal - armDy * armDy));
  final straightHandX = shoulderX - armDxStraight;
  final pulledHandX = shoulderX - _armPullDist;

  double handX;
  if (ph.inDrive) {
    final targetX = _lerp(_catchHandX, _finishHandX, _ease(ph.driveP));
    handX = max(targetX, straightHandX);
  } else if (inPauseA) {
    handX = _finishHandX;
  } else {
    handX = _lerp(straightHandX, pulledHandX, ph.armBend);
  }
  const handY = _handleY;

  // Effective arm bend
  final effectiveArmBend = ((handX - straightHandX) /
          max(1.0, pulledHandX - straightHandX))
      .clamp(0.0, 1.0);

  // Elbow: blend straight → IK
  const armFrac = _uArmLen / _armTotal;
  final lineElbowX = _lerp(shoulderX, handX, armFrac);
  final lineElbowY = _lerp(shoulderY, handY, armFrac);

  final adx = handX - shoulderX;
  final ady = handY - shoulderY;
  final aDist =
      sqrt(adx * adx + ady * ady).clamp(1.0, _armTotal - 0.5);
  final aBase = atan2(ady, adx);
  final cosB = ((_uArmLen * _uArmLen + aDist * aDist - _fArmLen * _fArmLen) /
          (2 * _uArmLen * aDist))
      .clamp(-1.0, 1.0);
  final offB = acos(cosB);
  final ikElbowX = shoulderX + _uArmLen * cos(aBase - offB);
  final ikElbowY = shoulderY + _uArmLen * sin(aBase - offB);

  final elbowBlend = (effectiveArmBend / 0.25).clamp(0.0, 1.0);
  final elbowX = _lerp(lineElbowX, ikElbowX, elbowBlend);
  final elbowY = _lerp(lineElbowY, ikElbowY, elbowBlend);

  // ── Muscle colors ──
  final inPauseC = gt >= _driveEnd && gt < _pauseEnd;
  final inRecovC = gt >= _pauseEnd;
  Color legC = isActive ? _colorRest : _colorInactive;
  Color torC = isActive ? _colorRest : _colorInactive;
  Color armC = isActive ? _colorRest : _colorInactive;

  if (isActive) {
    if (ph.inDrive) {
      final d = ph.driveP;
      // Legs: fade in, hold, fade out
      if (d < 0.06) {
        legC = _lerpColor(_colorRest, _colorActive, d / 0.06);
      } else if (d < 0.55) {
        legC = _colorActive;
      } else if (d < 0.70) {
        legC = _lerpColor(_colorActive, _colorRest, (d - 0.55) / 0.15);
      }

      // Torso: fade in, hold, fade out
      if (d >= 0.30 && d < 0.38) {
        torC = _lerpColor(_colorRest, _colorActive, (d - 0.30) / 0.08);
      } else if (d >= 0.38 && d < 0.75) {
        torC = _colorActive;
      } else if (d >= 0.75 && d < 0.87) {
        torC = _lerpColor(_colorActive, _colorRest, (d - 0.75) / 0.12);
      }
    } else if (inPauseC) {
      armC = _colorActive;
    } else if (inRecovC) {
      final r = (gt - _pauseEnd) / (1.0 - _pauseEnd);
      if (r < _recovArmEnd) {
        armC = _lerpColor(_colorActive, _colorRest, r / _recovArmEnd);
      }
    }

    // Arms: color tracks effectiveArmBend during drive
    if (effectiveArmBend > 0 && !inPauseC && !inRecovC) {
      armC = _lerpColor(
          _colorRest, _colorActive, (effectiveArmBend / 0.15).clamp(0, 1));
    }
  }

  return _Pose(
    ankle: const Offset(ankleX, ankleY),
    knee: Offset(kneeX, kneeY),
    hip: Offset(hipX, hipY),
    shoulder: Offset(shoulderX, shoulderY),
    neckTop: Offset(neckTopX, neckTopY),
    elbow: Offset(elbowX, elbowY),
    hand: Offset(handX, handY),
    head: Offset(headX, headY),
    seatX: seatX,
    legColor: legC,
    torsoColor: torC,
    armColor: armC,
  );
}

// ── CUSTOM PAINTER ──────────────────────────────────────────────────────────
class _RowingFigurePainter extends CustomPainter {
  final double progress;
  final bool isActive;

  _RowingFigurePainter({required this.progress, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    // Scale viewport region to fit widget size, centering the figure
    final scaleX = size.width / _viewWidth;
    final scaleY = size.height / _viewHeight;
    final scale = min(scaleX, scaleY);
    final offsetX = (size.width - _viewWidth * scale) / 2;
    final offsetY = (size.height - _viewHeight * scale) / 2;

    canvas.save();
    canvas.translate(offsetX - _viewLeft * scale, offsetY - _viewTop * scale);
    canvas.scale(scale);

    final pose = _computePose(progress, isActive);

    // ── Erg machine ──
    final ergColor = isActive
        ? _colorErg.withValues(alpha: 0.3)
        : _colorInactive.withValues(alpha: 0.2);

    // Rail
    canvas.drawLine(
      const Offset(100, _railY),
      const Offset(500, _railY),
      Paint()
        ..color = ergColor
        ..strokeWidth = _strokeRail
        ..strokeCap = StrokeCap.round,
    );

    // Seat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pose.seatX, _seatY, _seatW, _seatH),
        const Radius.circular(2),
      ),
      Paint()..color = isActive ? _colorErg : _colorInactive,
    );

    // ── Stick figure ──
    // Shin
    _drawLimb(canvas, pose.ankle, pose.knee, pose.legColor, _strokeLegs);
    // Thigh
    _drawLimb(canvas, pose.knee, pose.hip, pose.legColor, _strokeLegs);
    // Torso
    _drawLimb(
        canvas, pose.hip, pose.shoulder, pose.torsoColor, _strokeTorso);
    // Neck
    _drawLimb(canvas, pose.shoulder, pose.neckTop,
        isActive ? _colorRest : _colorInactive, _strokeNeck);
    // Upper arm
    _drawLimb(
        canvas, pose.shoulder, pose.elbow, pose.armColor, _strokeArms);
    // Forearm
    _drawLimb(canvas, pose.elbow, pose.hand, pose.armColor, _strokeArms);

    // Head
    canvas.drawCircle(
      pose.head,
      _headR,
      Paint()..color = isActive ? _colorRest : _colorInactive,
    );

    // Handle
    canvas.drawCircle(
      pose.hand,
      _handleR,
      Paint()..color = isActive ? _colorHandle : _colorInactive,
    );

    canvas.restore();
  }

  void _drawLimb(
      Canvas canvas, Offset from, Offset to, Color color, double width) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RowingFigurePainter old) =>
      old.progress != progress || old.isActive != isActive;
}

// ── WIDGET ──────────────────────────────────────────────────────────────────

/// Animated rowing figure — stick-figure rower with sequential muscle
/// activation (legs → body → arms). Speed matches [strokeRate] (spm).
/// When [strokeRate] is 0 or [isActive] is false, parks at catch position.
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
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: Size(constraints.maxWidth, widget.height),
                painter: _RowingFigurePainter(
                  progress: _controller.value,
                  isActive: widget.isActive,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
