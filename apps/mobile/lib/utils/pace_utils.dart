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

/// Format pace tenths (e.g. 1350) as "2:15".
/// Drops the tenths digit — whole seconds only.
String formatPace(int tenths) {
  if (tenths <= 0) return '--';
  final totalSeconds = tenths ~/ 10;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Convert watts to a formatted pace string like "1:58.6/500m".
String wattsToPaceString(int watts) {
  final tenths = wattsToPaceTenths(watts);
  if (tenths <= 0) return '--';
  return '${formatPace(tenths)}/500m';
}

/// Format pace tenths as "2:14" (no decimal) for FTP display.
/// Drops the tenths digit — whole seconds only, matching the web app.
String formatPaceNoTenths(int tenths) {
  if (tenths <= 0) return '--';
  final totalSeconds = tenths ~/ 10;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Convert watts to a no-tenths pace string like "1:58/500m" for FTP display.
String wattsToPaceStringNoTenths(int watts) {
  final tenths = wattsToPaceTenths(watts);
  if (tenths <= 0) return '--';
  return '${formatPaceNoTenths(tenths)}/500m';
}

/// Parse a pace string "m:ss" to tenths of a second per 500m.
/// Returns null if invalid. Example: "2:14" -> 1340
int? parsePace(String value) {
  final match = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(value.trim());
  if (match == null) return null;
  final mins = int.parse(match.group(1)!);
  final secs = int.parse(match.group(2)!);
  if (secs >= 60) return null;
  return mins * 600 + secs * 10;
}

/// Convert pace in tenths of a second per 500m back to watts.
/// Inverse of wattsToPaceTenths. Uses C2 formula: watts = 2.80 / (pace_seconds/500)^3
int paceTenthsToWatts(int tenths) {
  if (tenths <= 0) return 0;
  final paceSeconds = tenths / 10;
  return (2.80 / pow(paceSeconds / 500, 3)).round();
}

/// Default FTP for users who haven't taken an FTP test.
/// 150W ≈ 2:14/500m — moderate recreational rower baseline.
const int kDefaultFtpWatts = 150;

/// Resolve an intensity percentage to watts given an FTP.
/// Example: 75% of 200W FTP = 150W.
int intensityToWatts(int intensityPct, int ftpWatts) {
  return (ftpWatts * intensityPct / 100).round();
}

/// Resolve an intensity percentage to pace tenths given an FTP.
/// Example: 75% of 200W → 150W → wattsToPaceTenths(150).
int intensityToPaceTenths(int intensityPct, int ftpWatts) {
  return wattsToPaceTenths(intensityToWatts(intensityPct, ftpWatts));
}

/// Resolve an IntensityTarget to a pace range (min/max in tenths per 500m).
///
/// Returns (paceMin, paceMid, paceMax) where:
/// - paceMin = fastest acceptable pace (from max intensity %)
/// - paceMid = target pace (from midpoint intensity %)
/// - paceMax = slowest acceptable pace (from min intensity %)
///
/// Note: higher intensity % → more watts → faster pace (lower number).
({int paceMin, int paceMid, int paceMax}) resolveIntensityToPace(
  int intensityMin,
  int intensityMax,
  int ftpWatts,
) {
  final midPct = ((intensityMin + intensityMax) / 2).round();
  return (
    paceMin: intensityToPaceTenths(intensityMax, ftpWatts),
    paceMid: intensityToPaceTenths(midPct, ftpWatts),
    paceMax: intensityToPaceTenths(intensityMin, ftpWatts),
  );
}
