import 'package:flutter/material.dart';

/// Heart icon that pulses in time with [bpm]. Renders a bare static icon
/// when [bpm] is null or non-positive — no animation controller is allocated
/// in that case.
class PulsingHeartIcon extends StatefulWidget {
  final int? bpm;
  final double size;
  final Color color;

  const PulsingHeartIcon({
    super.key,
    this.bpm,
    this.size = 11,
    required this.color,
  });

  @override
  State<PulsingHeartIcon> createState() => _PulsingHeartIconState();
}

class _PulsingHeartIconState extends State<PulsingHeartIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scale;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PulsingHeartIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm) _sync();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _sync() {
    final bpm = widget.bpm;
    if (bpm == null || bpm <= 0) {
      _controller?.stop();
      _scale = null;
      return;
    }
    final period = Duration(milliseconds: (60000 / bpm).round());
    var c = _controller;
    if (c == null) {
      c = AnimationController(vsync: this, duration: period);
      _controller = c;
    } else if (c.duration != period) {
      c.duration = period;
    }
    // _scale may have been nulled during a prior positive→null transition;
    // rebuild it before the next paint or build() will render a bare icon.
    _scale ??= TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 65),
    ]).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    if (!c.isAnimating) c.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.favorite, size: widget.size, color: widget.color);
    final scale = _scale;
    if (scale == null) return RepaintBoundary(child: icon);
    return RepaintBoundary(
      child: ScaleTransition(scale: scale, child: icon),
    );
  }
}
