import 'dart:math';

import '../models/workout_segment.dart';

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
  if (tenths <= 0) return '--:--';
  final totalSeconds = tenths ~/ 10;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Convert watts to a formatted pace string like "1:58/500m".
String wattsToPaceStringNoTenths(int watts) {
  final tenths = wattsToPaceTenths(watts);
  if (tenths <= 0) return '--:--';
  return '${formatPace(tenths)}/500m';
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

/// Resolve an intensity percentage to a target pace in tenths per 500m.
///
/// Higher intensity % → more watts → faster pace (lower number).
int resolveIntensityToPace(int intensityPct, int ftpWatts) {
  return intensityToPaceTenths(intensityPct, ftpWatts);
}

/// Resolve a segment's target pace, checking [targetWatts] first
/// (absolute watts, used by ramp FTP test), then falling back to
/// [targetIntensity] × FTP. Returns 0 if the segment has no target.
int resolveSegmentTargetPace(WorkoutSegment segment, int ftpWatts) {
  if (segment.targetWatts != null) {
    return wattsToPaceTenths(segment.targetWatts!);
  }
  if (segment.targetIntensity != null) {
    return resolveIntensityToPace(segment.targetIntensity!, ftpWatts);
  }
  return 0;
}
