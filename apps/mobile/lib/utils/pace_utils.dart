import 'dart:math';

/// Convert watts to pace in tenths of a second per 500m.
///
/// Uses the standard Concept2 formula: watts = 2.80 / pace_per_meter³
/// So: pace_per_meter = (2.80 / watts)^(1/3)
/// And: pace_per_500m = pace_per_meter × 500
int wattsToPaceTenths(int watts) {
  if (watts <= 0) return 0;
  final pacePerMeter = pow(2.80 / watts, 1.0 / 3.0) as double;
  final pacePer500m = pacePerMeter * 500;
  return (pacePer500m * 10).round();
}

/// Format pace tenths (e.g. 1350) as "2:15.0".
/// Matches the web app's formatPace function.
String formatPace(int tenths) {
  if (tenths <= 0) return '--';
  final totalSeconds = tenths ~/ 10;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final remainder = tenths % 10;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.$remainder';
}

/// Convert watts to a formatted pace string like "1:58.6/500m".
String wattsToPaceString(int watts) {
  final tenths = wattsToPaceTenths(watts);
  if (tenths <= 0) return '--';
  return '${formatPace(tenths)}/500m';
}
