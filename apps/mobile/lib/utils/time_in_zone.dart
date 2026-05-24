import '../models/workout_time_sample.dart';
import 'hr_zones.dart';

/// Time spent in each HR zone (1–5), in seconds, for the given samples.
///
/// Each sample is weighted by the timestamp delta to the next sample; the
/// final sample uses the median delta so it isn't effectively zero. Samples
/// without a heart-rate value and zone-0 readings are dropped.
Map<int, double> timeInZone(
  List<WorkoutTimeSample> samples,
  int? restingHr,
  int maxHr,
) {
  if (samples.isEmpty || maxHr <= 0) return const {};

  final hrSamples = samples
      .where((s) => s.heartRate != null && s.heartRate! > 0)
      .toList(growable: false);
  if (hrSamples.isEmpty) return const {};

  final dts = List<double>.filled(hrSamples.length, 0);
  for (var i = 0; i < hrSamples.length - 1; i++) {
    final dtMs = hrSamples[i + 1].timestamp.inMilliseconds -
        hrSamples[i].timestamp.inMilliseconds;
    dts[i] = dtMs > 0 ? dtMs / 1000.0 : 1.0;
  }
  dts[dts.length - 1] = dts.length == 1 ? 1.0 : _median(dts.sublist(0, dts.length - 1));

  final result = <int, double>{};
  for (var i = 0; i < hrSamples.length; i++) {
    final zone = estimateHrZone(hrSamples[i].heartRate!, maxHr, restingHr: restingHr);
    if (zone < 1 || zone > 5) continue;
    result.update(zone, (v) => v + dts[i], ifAbsent: () => dts[i]);
  }
  return result;
}

/// Group samples by `segmentIndex`, returning `{segmentIndex: timeInZone}`.
/// Single O(N) pass — call once and reuse per-row instead of filtering N times.
Map<int, Map<int, double>> timeInZoneBySegment(
  List<WorkoutTimeSample> samples,
  int? restingHr,
  int maxHr,
) {
  final grouped = <int, List<WorkoutTimeSample>>{};
  for (final s in samples) {
    grouped.putIfAbsent(s.segmentIndex, () => []).add(s);
  }
  return grouped.map((k, v) => MapEntry(k, timeInZone(v, restingHr, maxHr)));
}

/// Sum `timeInZone` seconds across multiple sample sets (e.g. every workout).
Map<int, double> aggregateTimeInZone(
  Iterable<List<WorkoutTimeSample>> sampleSets,
  int? restingHr,
  int maxHr,
) {
  final total = <int, double>{};
  for (final samples in sampleSets) {
    final tiz = timeInZone(samples, restingHr, maxHr);
    tiz.forEach((k, v) => total.update(k, (x) => x + v, ifAbsent: () => v));
  }
  return total;
}

double _median(List<double> xs) {
  final sorted = [...xs]..sort();
  final n = sorted.length;
  return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}
