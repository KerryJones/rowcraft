// Orchestration tests for WorkoutSessionNotifier with a fake PM5 stream:
// - foreground service starts when the session becomes active and stops on finish
// - crash-recovery snapshots are written while rowing and on pending result
// - snapshot is cleared once the result is queued, and on discard
// - save failure surfaces saveProgress.error + a user-visible message
// - loadWorkout clears any previous snapshot and stops a stale service

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rowcraft/features/ble/ble_provider.dart';
import 'package:rowcraft/features/ble/hr_service.dart';
import 'package:rowcraft/features/ble/pm5_service.dart';
import 'package:rowcraft/features/history/history_provider.dart';
import 'package:rowcraft/features/plans/plans_provider.dart';
import 'package:rowcraft/features/workout/workout_engine.dart';
import 'package:rowcraft/features/workout/workout_provider.dart';
import 'package:rowcraft/models/achievement.dart';
import 'package:rowcraft/models/personal_record.dart';
import 'package:rowcraft/models/pm5_data.dart';
import 'package:rowcraft/models/workout.dart';
import 'package:rowcraft/models/workout_result.dart';
import 'package:rowcraft/models/workout_segment.dart';
import 'package:rowcraft/services/achievement_service.dart';
import 'package:rowcraft/services/c2_logbook_service.dart';
import 'package:rowcraft/services/foreground_session_service.dart';
import 'package:rowcraft/services/pr_service.dart';
import 'package:rowcraft/services/session_recovery_service.dart';
import 'package:rowcraft/services/supabase_service.dart';
import 'package:rowcraft/services/sync_service.dart';
import 'package:rowcraft/services/workout_repository.dart';

// ─── Fakes ──────────────────────────────────────────────────────────────────

class _FakePM5Service extends Fake implements PM5Service {
  final dataController = StreamController<PM5Data>.broadcast();
  final connectionController =
      StreamController<PM5ConnectionState>.broadcast();

  @override
  Stream<PM5Data> get pm5DataStream => dataController.stream;

  @override
  Stream<PM5ConnectionState> get connectionState =>
      connectionController.stream;

  @override
  bool get intentionalDisconnect => false;

  @override
  String? get connectedDeviceId => null;

  @override
  void dispose() {
    dataController.close();
    connectionController.close();
  }
}

class _FakeHrService extends Fake implements HrService {
  final hrController = StreamController<int>.broadcast();
  final connectionController = StreamController<HrConnectionState>.broadcast();

  @override
  Stream<int> get heartRateStream => hrController.stream;

  @override
  Stream<HrConnectionState> get connectionState => connectionController.stream;

  @override
  bool get intentionalDisconnect => false;

  @override
  void dispose() {
    hrController.close();
    connectionController.close();
  }
}

class _FakeSupabaseService extends Fake implements SupabaseService {
  @override
  String? get currentUserId => 'user-1';

  @override
  Future<Profile> getProfile() async =>
      throw Exception('offline'); // exercises the defaults fallback
}

class _FakeWorkoutRepository extends Fake implements WorkoutRepository {
  @override
  Future<Workout> getWorkout(String id) async {
    return Workout(
      id: id,
      authorId: 'author-1',
      title: 'Test Workout',
      workoutType: WorkoutType.singleTime,
      segments: const [
        WorkoutSegment(
          durationType: DurationType.time,
          durationValue: 600,
          targetIntensity: 80,
          targetStrokeRate: 22,
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }
}

class _FakeSyncService extends Fake implements SyncService {
  int queueCalls = 0;
  Object? throwOnQueue;
  WorkoutResult? lastQueued;

  @override
  Future<SyncOutcome> queueResult(WorkoutResult result) async {
    queueCalls++;
    lastQueued = result;
    if (throwOnQueue != null) throw throwOnQueue!;
    return const SyncOutcome(
      savedToSupabase: true,
      savedToC2: true,
      savedToPlexo: true,
      savedToStrava: true,
      resultId: 'result-1',
    );
  }
}

class _FakeForegroundSessionService implements ForegroundSessionService {
  int startCalls = 0;
  int stopCalls = 0;
  String? lastTitle;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> start({required String workoutTitle}) async {
    startCalls++;
    lastTitle = workoutTitle;
  }

  @override
  Future<void> update({required String text}) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

class _FakeSessionRecoveryService extends Fake
    implements SessionRecoveryService {
  final snapshots = <WorkoutResult>[];
  int clearCalls = 0;

  @override
  Future<void> saveSnapshot(WorkoutResult result) async {
    snapshots.add(result);
  }

  @override
  Future<void> clear() async {
    clearCalls++;
  }
}

class _FakePrService extends Fake implements PrService {
  @override
  bool get isLoaded => true;

  @override
  Future<List<PersonalRecord>> checkAndUpdatePRs(
          WorkoutResult result, String resultId) async =>
      [];
}

class _FakeAchievementService extends Fake implements AchievementService {
  @override
  bool get isLoaded => true;

  @override
  Future<List<Achievement>> checkAchievements({
    required String userId,
    required double totalDistance,
    required int totalWorkouts,
    required int completedPlanCount,
    required List<WorkoutResult> results,
    String? resultId,
  }) async =>
      [];
}

class _FakeC2LogbookService extends Fake implements C2LogbookService {
  @override
  Future<bool> isLinked() async => false;
}

// ─── Harness ────────────────────────────────────────────────────────────────

class _Harness {
  final ProviderContainer container;
  final _FakePM5Service pm5;
  final _FakeHrService hr;
  final _FakeSyncService sync;
  final _FakeForegroundSessionService foreground;
  final _FakeSessionRecoveryService recovery;

  _Harness._(this.container, this.pm5, this.hr, this.sync, this.foreground,
      this.recovery);

  factory _Harness.create() {
    final pm5 = _FakePM5Service();
    final hr = _FakeHrService();
    final sync = _FakeSyncService();
    final foreground = _FakeForegroundSessionService();
    final recovery = _FakeSessionRecoveryService();

    final container = ProviderContainer(overrides: [
      supabaseServiceProvider.overrideWithValue(_FakeSupabaseService()),
      syncServiceProvider.overrideWithValue(sync),
      workoutRepositoryProvider.overrideWithValue(_FakeWorkoutRepository()),
      foregroundSessionServiceProvider.overrideWithValue(foreground),
      sessionRecoveryServiceProvider.overrideWithValue(recovery),
      pm5ServiceProvider.overrideWithValue(pm5),
      hrServiceProvider.overrideWithValue(hr),
      prServiceProvider.overrideWithValue(_FakePrService()),
      achievementServiceProvider.overrideWithValue(_FakeAchievementService()),
      c2LogbookServiceProvider.overrideWithValue(_FakeC2LogbookService()),
      workoutHistoryProvider.overrideWith((ref) async => <WorkoutResult>[]),
      completedPlanCountProvider.overrideWith((ref) async => 0),
    ]);

    return _Harness._(container, pm5, hr, sync, foreground, recovery);
  }

  WorkoutSessionNotifier get notifier =>
      container.read(workoutSessionProvider.notifier);

  WorkoutSessionState get state => container.read(workoutSessionProvider);

  /// Emit a PM5 frame and let stream listeners run.
  Future<void> emitFrame({
    double distance = 100,
    int strokeRate = 24,
    Duration elapsed = const Duration(seconds: 30),
  }) async {
    pm5.dataController.add(PM5Data(
      elapsedTime: elapsed,
      distance: distance,
      pace: 1200,
      strokeRate: strokeRate,
      watts: 180,
      calories: 12,
      strokeCount: 20,
      intervalCount: 0,
      strokeRateUpdated: true,
    ));
    await pumpEventQueue();
  }

  void dispose() {
    container.dispose();
    pm5.dispose();
    hr.dispose();
  }
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Harness h;

  setUp(() => h = _Harness.create());
  tearDown(() => h.dispose());

  Future<void> loadAndStartRowing() async {
    await h.notifier.loadWorkout('workout-1');
    await pumpEventQueue();
    expect(h.state.engineState.phase, WorkoutPhase.ready);

    // First stroke auto-starts the session.
    await h.emitFrame();
    expect(h.state.engineState.phase, WorkoutPhase.rowing);
  }

  test('foreground service starts on first active phase and stops on finish',
      () async {
    await loadAndStartRowing();

    expect(h.foreground.startCalls, 1);
    expect(h.foreground.lastTitle, 'Test Workout');
    expect(h.foreground.stopCalls, 0);

    await h.notifier.stop();
    await pumpEventQueue();

    expect(h.state.engineState.phase, WorkoutPhase.finished);
    expect(h.foreground.stopCalls, 1);
    // No duplicate starts across the whole session.
    expect(h.foreground.startCalls, 1);
  });

  test('recovery snapshots are written while rowing', () async {
    await loadAndStartRowing();

    expect(h.recovery.snapshots, isNotEmpty);
    final snapshot = h.recovery.snapshots.first;
    expect(snapshot.userId, 'user-1');
    expect(snapshot.workoutId, 'workout-1');
    expect(snapshot.workoutName, 'Test Workout');
    expect(snapshot.totalDistance, 100);
  });

  test('pending result is built on stop and snapshot kept until saved',
      () async {
    await loadAndStartRowing();
    final clearsBeforeStop = h.recovery.clearCalls;

    await h.notifier.stop();
    await pumpEventQueue();

    expect(h.state.pendingResult, isNotNull);
    expect(h.state.pendingResult!.totalDistance, 100);
    // Stopping must NOT clear the snapshot — only saving/discarding does.
    expect(h.recovery.clearCalls, clearsBeforeStop);
  });

  test('saveResult queues the result and clears the snapshot', () async {
    await loadAndStartRowing();
    await h.notifier.stop();
    await pumpEventQueue();
    final clearsBeforeSave = h.recovery.clearCalls;

    await h.notifier.saveResult();

    expect(h.sync.queueCalls, 1);
    expect(h.sync.lastQueued!.userId, 'user-1');
    expect(h.recovery.clearCalls, greaterThan(clearsBeforeSave));
    expect(h.state.saveProgress, SaveProgress.done);
    expect(h.state.c2SyncStatus, C2SyncStatus.notLinked);
  });

  test('save failure surfaces error state and keeps the snapshot', () async {
    await loadAndStartRowing();
    await h.notifier.stop();
    await pumpEventQueue();

    h.sync.throwOnQueue = Exception('database is locked');
    final clearsBeforeSave = h.recovery.clearCalls;

    await h.notifier.saveResult();

    expect(h.state.saveProgress, SaveProgress.error);
    expect(h.state.syncError, contains('database is locked'));
    expect(h.recovery.clearCalls, clearsBeforeSave);
  });

  test('discardResult clears the snapshot', () async {
    await loadAndStartRowing();
    await h.notifier.stop();
    await pumpEventQueue();
    final clearsBeforeDiscard = h.recovery.clearCalls;

    h.notifier.discardResult();
    await pumpEventQueue();

    expect(h.state.pendingResult, isNull);
    expect(h.recovery.clearCalls, greaterThan(clearsBeforeDiscard));
  });

  test('loadWorkout clears any stale snapshot from a previous session',
      () async {
    await h.notifier.loadWorkout('workout-1');
    await pumpEventQueue();

    expect(h.recovery.clearCalls, greaterThan(0));
  });
}
