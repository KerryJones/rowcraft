import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pm5_data.dart';
import '../../models/workout_segment.dart';
import '../../models/workout_result.dart';
import '../../models/workout_time_sample.dart';
import '../../services/c2_logbook_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../ble/ble_provider.dart';
import '../ble/hr_service.dart';
import 'ftp_calculator.dart';
import 'workout_engine.dart';

/// Sentinel to distinguish "not passed" from "explicitly null" in copyWith.
const Object _sentinel = Object();

/// Tracks the progress of saving a workout result.
enum SaveProgress {
  idle,
  saving,
  savedLocally,
  savedToCloud,
  done,
  error,
}

/// Tracks C2 Logbook sync independently from the main save flow.
enum C2SyncStatus {
  /// Not checked yet.
  idle,
  /// User has not linked C2 account.
  notLinked,
  /// C2 sync succeeded.
  synced,
  /// C2 sync failed (will retry later).
  failed,
}

/// Combined state for the workout session UI.
class WorkoutSessionState {
  final String workoutTitle;
  final WorkoutEngineState engineState;
  final PM5Data pm5Data;
  final List<WorkoutSegment> expandedSegments;
  final List<String> workoutTags;
  final bool isLoading;
  final String? _error;

  /// FTP dialog state
  final bool showFtpDialog;
  final int? calculatedFtp;
  final String? ftpCalculationBasis;

  /// Plan context (set when launched from a training plan)
  final String? planId;
  final int? planWeek;
  final int? planSession;

  /// User's max heart rate from profile (for HR zone calculation).
  final int? maxHeartRate;

  /// Result waiting to be saved (after stop, before save).
  final WorkoutResult? pendingResult;

  /// Time-series data for post-workout graphs.
  final List<WorkoutTimeSample>? timeSamples;

  /// Tracks the progress of saving the result.
  final SaveProgress saveProgress;

  /// Tracks C2 Logbook sync independently.
  final C2SyncStatus c2SyncStatus;

  /// Last sync error message for display.
  final String? syncError;

  String? get error => _error;

  const WorkoutSessionState({
    this.workoutTitle = '',
    this.engineState = const WorkoutEngineState(),
    this.pm5Data = const PM5Data.zero(),
    this.expandedSegments = const [],
    this.workoutTags = const [],
    this.isLoading = false,
    String? error,
    this.showFtpDialog = false,
    this.calculatedFtp,
    this.ftpCalculationBasis,
    this.planId,
    this.planWeek,
    this.planSession,
    this.maxHeartRate,
    this.pendingResult,
    this.timeSamples,
    this.saveProgress = SaveProgress.idle,
    this.c2SyncStatus = C2SyncStatus.idle,
    this.syncError,
  }) : _error = error;

  WorkoutSessionState copyWith({
    String? workoutTitle,
    WorkoutEngineState? engineState,
    PM5Data? pm5Data,
    List<WorkoutSegment>? expandedSegments,
    List<String>? workoutTags,
    bool? isLoading,
    Object? error = _sentinel,
    bool? showFtpDialog,
    int? calculatedFtp,
    String? ftpCalculationBasis,
    Object? planId = _sentinel,
    Object? planWeek = _sentinel,
    Object? planSession = _sentinel,
    Object? maxHeartRate = _sentinel,
    Object? pendingResult = _sentinel,
    Object? timeSamples = _sentinel,
    SaveProgress? saveProgress,
    C2SyncStatus? c2SyncStatus,
    Object? syncError = _sentinel,
  }) {
    return WorkoutSessionState(
      workoutTitle: workoutTitle ?? this.workoutTitle,
      engineState: engineState ?? this.engineState,
      pm5Data: pm5Data ?? this.pm5Data,
      expandedSegments: expandedSegments ?? this.expandedSegments,
      workoutTags: workoutTags ?? this.workoutTags,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? _error : error as String?,
      showFtpDialog: showFtpDialog ?? this.showFtpDialog,
      calculatedFtp: calculatedFtp ?? this.calculatedFtp,
      ftpCalculationBasis: ftpCalculationBasis ?? this.ftpCalculationBasis,
      planId: planId == _sentinel ? this.planId : planId as String?,
      planWeek: planWeek == _sentinel ? this.planWeek : planWeek as int?,
      planSession:
          planSession == _sentinel ? this.planSession : planSession as int?,
      maxHeartRate:
          maxHeartRate == _sentinel ? this.maxHeartRate : maxHeartRate as int?,
      pendingResult:
          pendingResult == _sentinel ? this.pendingResult : pendingResult as WorkoutResult?,
      timeSamples:
          timeSamples == _sentinel ? this.timeSamples : timeSamples as List<WorkoutTimeSample>?,
      saveProgress: saveProgress ?? this.saveProgress,
      c2SyncStatus: c2SyncStatus ?? this.c2SyncStatus,
      syncError: syncError == _sentinel ? this.syncError : syncError as String?,
    );
  }
}

class WorkoutSessionNotifier extends StateNotifier<WorkoutSessionState> {
  final SupabaseService _supabaseService;
  final SyncService _syncService;
  final Ref _ref;

  WorkoutEngine? _engine;

  /// Supabase-assigned result ID, set after successful save.
  String? _savedResultId;
  StreamSubscription<WorkoutEngineState>? _engineSub;
  StreamSubscription<PM5Data>? _pm5BleSubscription;
  StreamSubscription<int>? _hrBleSubscription;
  StreamSubscription<HrConnectionState>? _hrConnectionSub;

  /// The latest standalone HR value for merging with PM5 data.
  int? _lastStandaloneHr;

  /// Recorded when start() is called — used for accurate startedAt.
  DateTime? _startedAt;

  /// BLE data stream controller — feeds into the workout engine.
  final _pm5Controller = StreamController<PM5Data>.broadcast();

  WorkoutSessionNotifier(this._supabaseService, this._syncService, this._ref)
      : super(const WorkoutSessionState()) {
    _subscribeToBle();
  }

  /// Subscribe to BLE PM5 data, standalone HR, and HR connection state.
  void _subscribeToBle() {
    // Listen to PM5 BLE data
    final pm5Stream = _ref.read(pm5ServiceProvider).pm5DataStream;
    _pm5BleSubscription = pm5Stream.listen((pm5Data) {
      // Merge standalone HR — prefer chest strap (more accurate)
      PM5Data merged = pm5Data;
      if (_lastStandaloneHr != null) {
        merged = pm5Data.copyWith(heartRate: _lastStandaloneHr);
      }

      _pm5Controller.add(merged);
      state = state.copyWith(pm5Data: merged);
    });

    // Listen to standalone HR data
    final hrStream = _ref.read(hrServiceProvider).heartRateStream;
    _hrBleSubscription = hrStream.listen((hr) {
      _lastStandaloneHr = hr;

      // If no PM5 data is flowing, still update the HR display
      if (state.pm5Data.heartRate != hr) {
        final updated = state.pm5Data.copyWith(heartRate: hr);
        state = state.copyWith(pm5Data: updated);
      }
    });

    // Clear stale HR when the HR monitor disconnects
    final hrService = _ref.read(hrServiceProvider);
    _hrConnectionSub = hrService.connectionState.listen((connState) {
      if (connState == HrConnectionState.disconnected) {
        _lastStandaloneHr = null;
      }
    });
  }

  /// Push PM5 data from BLE layer (kept for backward compatibility).
  void onPM5Data(PM5Data data) {
    _pm5Controller.add(data);
    state = state.copyWith(pm5Data: data);
  }

  /// Load a workout definition and prepare the engine.
  Future<void> loadWorkout(
    String workoutId, {
    String? planId,
    int? planWeek,
    int? planSession,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      planId: planId,
      planWeek: planWeek,
      planSession: planSession,
    );

    try {
      final workout = await _supabaseService.getWorkout(workoutId);

      // Fetch user's max heart rate from profile (non-blocking on failure)
      int? maxHr;
      try {
        final profile = await _supabaseService.getProfile();
        maxHr = profile.maxHeartRate;
      } catch (_) {
        // Non-critical — fall back to default 190
      }

      final isFtpTest = workout.tags.contains('ftp') ||
          workout.tags.contains('test');
      _engine = WorkoutEngine(
        workout: workout,
        pm5Stream: _pm5Controller.stream,
        paceFailThreshold: isFtpTest ? 10 : 0,
      );

      _engineSub = _engine!.stateStream.listen((engineState) {
        // Record start time on first transition out of ready/idle
        if (_startedAt == null &&
            engineState.phase == WorkoutPhase.rowing) {
          _startedAt = DateTime.now();
        }
        state = state.copyWith(engineState: engineState);

        // When engine finishes on its own (all segments complete or pace fail),
        // build the pending result so the summary screen appears.
        if (engineState.phase == WorkoutPhase.finished &&
            state.pendingResult == null) {
          _buildPendingResult();
        }
      });

      state = state.copyWith(
        workoutTitle: workout.title,
        expandedSegments: _engine!.expandedSegments,
        workoutTags: workout.tags,
        maxHeartRate: maxHr,
        isLoading: false,
      );

      // Enter ready phase — workout starts when rower takes first stroke
      _engine!.ready();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load workout: $e',
      );
    }
  }

  /// Start the workout.
  void start() {
    _startedAt = DateTime.now();
    _engine?.start();
  }

  /// Pause the workout.
  void pause() {
    _engine?.pause();
  }

  /// Resume after pause.
  void resume() {
    _engine?.resume();
  }

  /// Stop the workout and build a pending result (does NOT save).
  Future<void> stop() async {
    if (_engine == null) return;
    _engine!.stop();
    // The engine listener will detect finished and call _buildPendingResult().
    // But if it already fired synchronously, this is a no-op (guarded by null check).
    _buildPendingResult();
  }

  /// Build WorkoutResult from engine data and store as pendingResult.
  /// Safe to call multiple times — no-ops if already built.
  void _buildPendingResult() {
    if (_engine == null || state.pendingResult != null) return;

    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final now = DateTime.now();
    final data = state.pm5Data;
    final splits = _engine!.completedSplits;

    // Don't save empty results (e.g. stopped during countdown or before rowing)
    if (splits.isEmpty && data.distance == 0) return;

    // Use recorded start time (not back-computed from BLE frame)
    final startedAt = _startedAt ?? now.subtract(data.elapsedTime);

    // Compute duration-weighted averages from completed splits
    int avgSplit = data.pace; // fallback to instantaneous
    int avgSR = data.strokeRate;
    int avgW = data.watts;
    if (splits.isNotEmpty) {
      double paceDW = 0, srDW = 0, wattsDW = 0, totalMs = 0;
      for (final s in splits) {
        final ms = s.time.inMilliseconds.toDouble();
        paceDW += s.avgPace * ms;
        srDW += s.avgStrokeRate * ms;
        wattsDW += s.avgWatts * ms;
        totalMs += ms;
      }
      if (totalMs > 0) {
        avgSplit = (paceDW / totalMs).round();
        avgSR = (srDW / totalMs).round();
        avgW = (wattsDW / totalMs).round();
      }
    }

    final result = WorkoutResult(
      id: '', // Let Supabase generate
      userId: userId,
      workoutId: _engine!.workout.id,
      startedAt: startedAt,
      finishedAt: now,
      totalDistance: data.distance,
      totalTime: data.elapsedTime,
      avgSplit: avgSplit,
      avgStrokeRate: avgSR,
      avgHeartRate: data.heartRate,
      avgWatts: avgW,
      calories: data.calories,
      splits: splits,
    );

    state = state.copyWith(
      pendingResult: result,
      timeSamples: _engine!.timeSamples,
    );

    // Detect FTP test
    final tags = state.workoutTags;
    if (tags.contains('ftp') && splits.isNotEmpty) {
      final isRamp = tags.contains('ramp');
      int ftp;
      String basis;

      if (isRamp) {
        ftp = FtpCalculator.calculateRampFtp(
          splits,
          _engine!.expandedSegments,
        );
        // Find peak watts for display
        int peak = 0;
        for (final s in splits) {
          if (s.avgWatts > peak) peak = s.avgWatts;
        }
        basis = '65% of peak ${peak}W';
      } else {
        ftp = FtpCalculator.calculate20MinFtp(splits);
        // Compute duration-weighted avg for display
        double wSum = 0, dSum = 0;
        for (final s in splits) {
          final d = s.time.inMilliseconds.toDouble();
          wSum += s.avgWatts * d;
          dSum += d;
        }
        final displayAvg = dSum > 0 ? (wSum / dSum).round() : 0;
        basis = '95% of avg ${displayAvg}W';
      }

      if (ftp > 0) {
        state = state.copyWith(
          showFtpDialog: true,
          calculatedFtp: ftp,
          ftpCalculationBasis: basis,
        );
      }
    }
  }

  /// Save the pending result (queue for sync, record plan progress).
  Future<void> saveResult() async {
    final result = state.pendingResult;
    if (result == null) return;

    state = state.copyWith(saveProgress: SaveProgress.saving);
    _savedResultId = null;

    try {
      // Queue for offline-first sync (SQLite write + Supabase attempt)
      final outcome = await _syncService.queueResult(result);
      state = state.copyWith(saveProgress: SaveProgress.savedLocally);

      // Record plan progress if launched from a training plan
      if (state.planId != null &&
          state.planWeek != null &&
          state.planSession != null) {
        try {
          await _supabaseService.completePlanSession(
            state.planId!,
            state.planWeek!,
            state.planSession!,
            null,
          );
        } catch (_) {
          // Non-critical — don't block workout completion
        }
      }

      _savedResultId = outcome.resultId;

      // Cloud status from actual sync outcome
      if (outcome.savedToSupabase) {
        state = state.copyWith(saveProgress: SaveProgress.savedToCloud);
      } else if (outcome.error != null) {
        state = state.copyWith(syncError: outcome.error);
      }

      // C2 Logbook status from actual sync outcome.
      // Not-linked is encoded as savedToC2: true (marked done) with no error.
      if (outcome.savedToC2 && outcome.error == null) {
        // Either synced successfully or user is not C2-linked
        final c2Service = _ref.read(c2LogbookServiceProvider);
        final isLinked = await c2Service.isLinked();
        state = state.copyWith(
          c2SyncStatus: isLinked ? C2SyncStatus.synced : C2SyncStatus.notLinked,
        );
      } else {
        state = state.copyWith(
          c2SyncStatus: C2SyncStatus.failed,
          syncError: outcome.error ?? 'C2 sync failed — will retry',
        );
      }

      state = state.copyWith(saveProgress: SaveProgress.done);
    } catch (e) {
      state = state.copyWith(saveProgress: SaveProgress.error);
    }
  }

  /// Discard the pending result without saving.
  void discardResult() {
    state = state.copyWith(
      pendingResult: null,
      timeSamples: null,
      saveProgress: SaveProgress.idle,
    );
  }

  /// Save FTP result to Supabase.
  Future<void> saveFtp(int watts) async {
    if (watts <= 0) return;

    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final record = FtpRecord(
      id: '',
      userId: userId,
      testedAt: DateTime.now(),
      ftpWatts: watts,
      testType: state.workoutTags.contains('ramp') ? 'ramp' : '20min',
      sourceResultId: _savedResultId,
    );

    await _supabaseService.saveFtpRecord(record);
    await _supabaseService.updateProfileFtp(watts);

    state = state.copyWith(showFtpDialog: false);
  }

  /// Dismiss FTP dialog without saving.
  void dismissFtpDialog() {
    state = state.copyWith(showFtpDialog: false);
  }

  @override
  void dispose() {
    _engineSub?.cancel();
    _engine?.dispose();
    _pm5Controller.close();
    _pm5BleSubscription?.cancel();
    _hrBleSubscription?.cancel();
    _hrConnectionSub?.cancel();
    super.dispose();
  }
}

final workoutSessionProvider =
    StateNotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>((ref) {
  return WorkoutSessionNotifier(
    ref.watch(supabaseServiceProvider),
    ref.watch(syncServiceProvider),
    ref,
  );
});
