// Tests for SessionRecoveryService:
// - snapshot save/load roundtrip preserves the partial result
// - missing snapshot loads as null
// - clear() removes the snapshot
// - corrupt snapshot is discarded (null) and deleted
// - stale snapshot (older than maxAge) is discarded

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rowcraft/models/workout_result.dart';
import 'package:rowcraft/models/workout_time_sample.dart';
import 'package:rowcraft/services/session_recovery_service.dart';

WorkoutResult _partialResult() {
  return WorkoutResult(
    id: '',
    userId: 'user-1',
    workoutId: 'workout-1',
    workoutName: '4x2000m',
    startedAt: DateTime(2026, 7, 1, 6, 0),
    finishedAt: DateTime(2026, 7, 1, 6, 24),
    totalDistance: 5200,
    totalTime: const Duration(minutes: 24),
    avgSplit: 1250,
    avgStrokeRate: 22,
    avgHeartRate: 152,
    avgWatts: 185,
    calories: 310,
    strokeCount: 530,
    timezone: 'America/New_York',
    splits: const [
      SplitData(
        intervalIndex: 0,
        distance: 2000,
        time: Duration(minutes: 8, seconds: 20),
        avgPace: 1250,
        avgStrokeRate: 22,
        avgWatts: 185,
        avgHeartRate: 148,
        calories: 120,
      ),
    ],
    timeSamples: const [
      WorkoutTimeSample(
        timestamp: Duration(seconds: 1),
        distance: 5.2,
        pace: 1250,
        strokeRate: 22,
        heartRate: 120,
        segmentIndex: 0,
      ),
    ],
  );
}

void main() {
  late Directory tempDir;
  late SessionRecoveryService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recovery_test');
    service = SessionRecoveryService(getDirectory: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  File snapshotFile() => File(p.join(tempDir.path, 'in_progress_session.json'));

  test('loadSnapshot returns null when no snapshot exists', () async {
    expect(await service.loadSnapshot(), isNull);
  });

  test('save/load roundtrip preserves the partial result', () async {
    final original = _partialResult();
    await service.saveSnapshot(original);

    final loaded = await service.loadSnapshot();
    expect(loaded, isNotNull);
    expect(loaded!.userId, original.userId);
    expect(loaded.workoutId, original.workoutId);
    expect(loaded.workoutName, original.workoutName);
    expect(loaded.startedAt, original.startedAt);
    expect(loaded.totalDistance, original.totalDistance);
    expect(loaded.totalTime, original.totalTime);
    expect(loaded.avgSplit, original.avgSplit);
    expect(loaded.avgHeartRate, original.avgHeartRate);
    expect(loaded.timezone, original.timezone);
    expect(loaded.splits, hasLength(1));
    expect(loaded.splits.first.distance, 2000);
    expect(loaded.splits.first.avgPace, 1250);
    expect(loaded.timeSamples, hasLength(1));
    expect(loaded.timeSamples.first.pace, 1250);
    expect(loaded.timeSamples.first.heartRate, 120);
  });

  test('newer snapshot overwrites the previous one', () async {
    await service.saveSnapshot(_partialResult());
    await service
        .saveSnapshot(_partialResult().copyWith(totalDistance: 6000));

    final loaded = await service.loadSnapshot();
    expect(loaded!.totalDistance, 6000);
  });

  test('clear removes the snapshot', () async {
    await service.saveSnapshot(_partialResult());
    expect(await snapshotFile().exists(), isTrue);

    await service.clear();
    expect(await snapshotFile().exists(), isFalse);
    expect(await service.loadSnapshot(), isNull);
  });

  test('clear is a no-op when no snapshot exists', () async {
    await service.clear();
    expect(await service.loadSnapshot(), isNull);
  });

  test('corrupt snapshot is discarded and deleted', () async {
    await snapshotFile().writeAsString('{not valid json!!');

    expect(await service.loadSnapshot(), isNull);
    expect(await snapshotFile().exists(), isFalse);
  });

  test('snapshot with missing fields is discarded', () async {
    await snapshotFile().writeAsString(jsonEncode({'saved_at': 'nonsense'}));

    expect(await service.loadSnapshot(), isNull);
  });

  test('stale snapshot is discarded', () async {
    final staleTime =
        DateTime.now().subtract(SessionRecoveryService.maxAge * 2);
    await snapshotFile().writeAsString(jsonEncode({
      'saved_at': staleTime.toIso8601String(),
      'result': _partialResult().toJson(),
    }));

    expect(await service.loadSnapshot(), isNull);
    expect(await snapshotFile().exists(), isFalse);
  });

  test('fresh snapshot within maxAge is returned', () async {
    final recentTime =
        DateTime.now().subtract(const Duration(minutes: 5));
    await snapshotFile().writeAsString(jsonEncode({
      'saved_at': recentTime.toIso8601String(),
      'result': _partialResult().toJson(),
    }));

    expect(await service.loadSnapshot(), isNotNull);
  });
}
