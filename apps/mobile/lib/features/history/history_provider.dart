import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/workout_result.dart';
import '../../services/supabase_service.dart';

/// Fetches the current user's workout history.
final workoutHistoryProvider =
    FutureProvider<List<WorkoutResult>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final userId = service.currentUserId;
  if (userId == null) return [];
  return service.getResults(userId);
});

/// Single workout result by ID.
final workoutResultProvider =
    FutureProvider.family<WorkoutResult?, String>((ref, resultId) async {
  final results = await ref.watch(workoutHistoryProvider.future);
  try {
    return results.firstWhere((r) => r.id == resultId);
  } catch (_) {
    return null;
  }
});

/// Summary statistics across all results.
final historySummaryProvider =
    FutureProvider<HistorySummary>((ref) async {
  final results = await ref.watch(workoutHistoryProvider.future);
  return HistorySummary.fromResults(results);
});

class HistorySummary {
  final int totalWorkouts;
  final double totalDistance;
  final Duration totalTime;
  final int? bestSplit;
  final double avgStrokeRate;

  const HistorySummary({
    required this.totalWorkouts,
    required this.totalDistance,
    required this.totalTime,
    this.bestSplit,
    required this.avgStrokeRate,
  });

  factory HistorySummary.fromResults(List<WorkoutResult> results) {
    if (results.isEmpty) {
      return const HistorySummary(
        totalWorkouts: 0,
        totalDistance: 0,
        totalTime: Duration.zero,
        avgStrokeRate: 0,
      );
    }

    double totalDist = 0;
    Duration totalTime = Duration.zero;
    int? bestSplit;
    int srSum = 0;

    for (final r in results) {
      totalDist += r.totalDistance;
      totalTime += r.totalTime;
      srSum += r.avgStrokeRate;

      if (r.avgSplit > 0) {
        if (bestSplit == null || r.avgSplit < bestSplit) {
          bestSplit = r.avgSplit;
        }
      }
    }

    return HistorySummary(
      totalWorkouts: results.length,
      totalDistance: totalDist,
      totalTime: totalTime,
      bestSplit: bestSplit,
      avgStrokeRate: srSum / results.length,
    );
  }

  String get totalDistanceFormatted {
    if (totalDistance >= 1000000) {
      return '${(totalDistance / 1000).toStringAsFixed(0)}km';
    }
    if (totalDistance >= 1000) {
      return '${(totalDistance / 1000).toStringAsFixed(1)}km';
    }
    return '${totalDistance.toInt()}m';
  }

  String get bestSplitFormatted {
    if (bestSplit == null) return '--:--';
    final minutes = bestSplit! ~/ 600;
    final remaining = bestSplit! % 600;
    final seconds = remaining ~/ 10;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
