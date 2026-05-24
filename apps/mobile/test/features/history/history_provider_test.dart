import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/features/history/history_provider.dart';
import 'package:rowcraft/models/workout_result.dart';

void main() {
  WorkoutResult result({
    String id = 'r',
    DateTime? startedAt,
    int totalDistance = 5000,
    int totalTimeMs = 1200000, // 20 min
    int avgSplit = 1050, // 1:45
    int avgStrokeRate = 28,
    int avgWatts = 200,
    int calories = 250,
  }) {
    final started = startedAt ?? DateTime.utc(2026, 1, 1, 10, 0, 0);
    return WorkoutResult(
      id: id,
      userId: 'u',
      startedAt: started,
      finishedAt: started.add(Duration(milliseconds: totalTimeMs)),
      totalDistance: totalDistance.toDouble(),
      totalTime: Duration(milliseconds: totalTimeMs),
      avgSplit: avgSplit,
      avgStrokeRate: avgStrokeRate,
      avgWatts: avgWatts,
      calories: calories,
    );
  }

  group('HistorySummary.fromResults', () {
    test('empty list yields all-zero summary', () {
      final s = HistorySummary.fromResults(const []);
      expect(s.totalWorkouts, 0);
      expect(s.totalDistance, 0);
      expect(s.totalTime, Duration.zero);
      expect(s.bestSplit, isNull);
      expect(s.avgStrokeRate, 0);
      expect(s.activeDays, 0);
      expect(s.totalCalories, 0);
      expect(s.avgWatts, 0);
      expect(s.avgPaceWeighted, 0);
    });

    test('single workout matches its own metrics', () {
      final r = result(
        totalDistance: 6000,
        totalTimeMs: 1500000, // 25 min
        avgSplit: 1100,
        avgStrokeRate: 27,
        avgWatts: 190,
        calories: 320,
      );
      final s = HistorySummary.fromResults([r]);
      expect(s.totalWorkouts, 1);
      expect(s.totalDistance, 6000);
      expect(s.totalTime, const Duration(milliseconds: 1500000));
      expect(s.bestSplit, 1100);
      expect(s.avgStrokeRate, 27);
      expect(s.activeDays, 1);
      expect(s.totalCalories, 320);
      expect(s.avgWatts, 190);
      expect(s.avgPaceWeighted, 1100);
    });

    test('two workouts on same local calendar day count as one active day', () {
      final morning = DateTime(2026, 3, 5, 8, 0, 0);
      final evening = DateTime(2026, 3, 5, 19, 0, 0);
      final s = HistorySummary.fromResults([
        result(id: 'a', startedAt: morning),
        result(id: 'b', startedAt: evening),
      ]);
      expect(s.totalWorkouts, 2);
      expect(s.activeDays, 1);
    });

    test('two workouts on different local days count as two active days', () {
      final s = HistorySummary.fromResults([
        result(id: 'a', startedAt: DateTime(2026, 3, 5, 8, 0, 0)),
        result(id: 'b', startedAt: DateTime(2026, 3, 6, 8, 0, 0)),
      ]);
      expect(s.activeDays, 2);
    });

    test('duration-weighted avg pace matches workout_provider aggregation', () {
      // 10 min @ 1100 pace + 20 min @ 1000 pace → weighted = (1100*600k + 1000*1.2M) / 1.8M = 1033.33 → 1033
      final s = HistorySummary.fromResults([
        result(
          id: 'a',
          totalTimeMs: 600000,
          avgSplit: 1100,
          avgStrokeRate: 26,
          avgWatts: 180,
        ),
        result(
          id: 'b',
          totalTimeMs: 1200000,
          avgSplit: 1000,
          avgStrokeRate: 30,
          avgWatts: 220,
        ),
      ]);
      expect(s.avgPaceWeighted, 1033);
      // weighted watts: (180*600k + 220*1.2M)/1.8M = 206.66 → 207
      expect(s.avgWatts, 207);
      // weighted stroke rate: (26*600k + 30*1.2M)/1.8M = 28.66
      expect(s.avgStrokeRate, closeTo(28.666, 0.01));
    });

    test('sums calories and distance across results', () {
      final s = HistorySummary.fromResults([
        result(id: 'a', totalDistance: 3000, calories: 150),
        result(id: 'b', totalDistance: 4500, calories: 240),
      ]);
      expect(s.totalDistance, 7500);
      expect(s.totalCalories, 390);
    });

    test('best split tracks the minimum (fastest) avgSplit', () {
      final s = HistorySummary.fromResults([
        result(id: 'a', avgSplit: 1100),
        result(id: 'b', avgSplit: 980),
        result(id: 'c', avgSplit: 1050),
      ]);
      expect(s.bestSplit, 980);
    });
  });
}
