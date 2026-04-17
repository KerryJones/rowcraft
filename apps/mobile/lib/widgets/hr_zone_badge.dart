import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact HR zone badge — colored pill showing "Z2" or "~Z3".
///
/// Used in workout HUD contexts (classic mode current-segment bar,
/// compact mode HR tile) where space is tight and glanceability matters.
class HrZoneBadge extends StatelessWidget {
  final int zone;
  final Color color;
  final bool estimated;

  const HrZoneBadge({
    super.key,
    required this.zone,
    required this.color,
    this.estimated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${estimated ? '~' : ''}Z$zone',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
