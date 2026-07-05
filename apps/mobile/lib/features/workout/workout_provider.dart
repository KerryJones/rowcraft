import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../models/achievement.dart';
import '../../models/personal_record.dart';
import '../../models/pm5_data.dart';
import '../../models/workout_segment.dart';
import '../../models/workout_result.dart';
import '../../models/workout_time_sample.dart';
import '../../services/achievement_service.dart';
import '../../services/audio_service.dart';
import '../../services/c2_logbook_service.dart';
import '../../services/foreground_session_service.dart';
import '../../services/pr_service.dart';
import '../../services/session_recovery_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../services/workout_repository.dart';
import '../../utils/app_log.dart';
import '../../utils/hr_zones.dart' show ZoneSystem;
import '../../utils/pace_utils.dart';
import '../ble/ble_provider.dart';
import '../ble/csafe_commands.dart';
import '../ble/hr_service.dart';
import '../ble/pm5_service.dart';
import '../history/history_provider.dart';
import '../plans/plans_provider.dart';
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

  /// FTP result state
  final int? calculatedFtp;
  final String? ftpCalculationBasis;

  /// FTP test metadata for the result screen
  final int? previousFtpWatts;
  final int? rampStagesCompleted;
  final int? rampTotalStages;
  final int? rampPeakWatts;

  /// Plan context (set when launched from a training plan)
  final String? planId;
  final int? planWeek;
  final int? planSession;

  /// User's max heart rate from profile (for HR zone calculation).
  final int? maxHeartRate;

  /// User's resting heart rate from profile (for HRR/Karvonen calculation).
  final int? restingHeartRate;

  /// User's zone system preference (standard or rowing).
  final ZoneSystem zoneSystem;

  /// User's FTP in watts (for resolving intensity targets to pace).
  final int ftpWatts;

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

  /// PRs broken during this save (for summary screen display).
  final List<PersonalRecord> newPRs;

  /// Achievements earned during this save (for summary screen display).
  final List<Achievement> newAchievements;

  String? get error => _error;

  const WorkoutSessionState({
    this.workoutTitle = '',
    this.engineState = const WorkoutEngineState(),
    this.pm5Data = const PM5Data.zero(),
    this.expandedSegments = const [],
    this.workoutTags = const [],
    this.isLoading = false,
    String? error,
    this.calculatedFtp,
    this.ftpCalculationBasis,
    this.previousFtpWatts,
    this.rampStagesCompleted,
    this.rampTotalStages,
    this.rampPeakWatts,
    this.planId,
    this.planWeek,
    this.planSession,
    this.maxHeartRate,
    this.restingHeartRate,
    this.zoneSystem = ZoneSystem.rowing,
    this.ftpWatts = kDefaultFtpWatts,
    this.pendingResult,
    this.timeSamples,
    this.saveProgress = SaveProgress.idle,
    this.c2SyncStatus = C2SyncStatus.idle,
    this.syncError,
    this.newPRs = const [],
    this.newAchievements = const [],
  }) : _error = error;

  WorkoutSessionState copyWith({
    String? workoutTitle,
    WorkoutEngineState? engineState,
    PM5Data? pm5Data,
    List<WorkoutSegment>? expandedSegments,
    List<String>? workoutTags,
    bool? isLoading,
    Object? error = _sentinel,
    int? calculatedFtp,
    String? ftpCalculationBasis,
    Object? previousFtpWatts = _sentinel,
    Object? rampStagesCompleted = _sentinel,
    Object? rampTotalStages = _sentinel,
    Object? rampPeakWatts = _sentinel,
    Object? planId = _sentinel,
    Object? planWeek = _sentinel,
    Object? planSession = _sentinel,
    Object? maxHeartRate = _sentinel,
    Object? restingHeartRate = _sentinel,
    ZoneSystem? zoneSystem,
    int? ftpWatts,
    Object? pendingResult = _sentinel,
    Object? timeSamples = _sentinel,
    SaveProgress? saveProgress,
    C2SyncStatus? c2SyncStatus,
    Object? syncError = _sentinel,
    List<PersonalRecord>? newPRs,
    List<Achievement>? newAchievements,
  }) {
    return WorkoutSessionState(
      workoutTitle: workoutTitle ?? this.workoutTitle,
      engineState: engineState ?? this.engineState,
      pm5Data: pm5Data ?? this.pm5Data,
      expandedSegments: expandedSegments ?? this.expandedSegments,
      workoutTags: workoutTags ?? this.workoutTags,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? _error : error as String?,
      calculatedFtp: calculatedFtp ?? this.calculatedFtp,
      ftpCalculationBasis: ftpCalculationBasis ?? this.ftpCalculationBasis,
      previousFtpWatts:
          previousFtpWatts == _sentinel ? this.previousFtpWatts : previousFtpWatts as int?,
      rampStagesCompleted:
          rampStagesCompleted == _sentinel ? this.rampStagesCompleted : rampStagesCompleted as int?,
      rampTotalStages:
          rampTotalStages == _sentinel ? this.rampTotalStages : rampTotalStages as int?,
      rampPeakWatts:
          rampPeakWatts == _sentinel ? this.rampPeakWatts : rampPeakWatts as int?,
      planId: planId == _sentinel ? this.planId : planId as String?,
      planWeek: planWeek == _sentinel ? this.planWeek : planWeek as int?,
      planSession:
          planSession == _sentinel ? this.planSession : planSession as int?,
      maxHeartRate:
          maxHeartRate == _sentinel ? this.maxHeartRate : maxHeartRate as int?,
      restingHeartRate:
          restingHeartRate == _sentinel ? this.restingHeartRate : restingHeartRate as int?,
      zoneSystem: zoneSystem ?? this.zoneSystem,
      ftpWatts: ftpWatts ?? this.ftpWatts,
      pendingResult:
          pendingResult == _sentinel ? this.pendingResult : pendingResult as WorkoutResult?,
      timeSamples:
          timeSamples == _sentinel ? this.timeSamples : timeSamples as List<WorkoutTimeSample>?,
      saveProgress: saveProgress ?? this.saveProgress,
      c2SyncStatus: c2SyncStatus ?? this.c2SyncStatus,
      syncError: syncError == _sentinel ? this.syncError : syncError as String?,
      newPRs: newPRs ?? this.newPRs,
      newAchievements: newAchievements ?? this.newAchievements,
    );
  }
}

class WorkoutSessionNotifier extends Notifier<WorkoutSessionState> {
  late SupabaseService _supabaseService;
  late SyncService _syncService;
  late WorkoutRepository _workoutRepository;
  late ForegroundSessionService _foregroundService;
  late SessionRecoveryService _recoveryService;

  WorkoutEngine? _engine;

  /// True while the workout foreground service is running.
  bool _foregroundServiceRunning = false;

  /// Last time a recovery snapshot was written (throttled to every few
  /// seconds — writing on every engine tick would hammer the disk).
  DateTime? _lastSnapshotAt;

  /// Minimum interval between recovery snapshots.
  static const _snapshotInterval = Duration(seconds: 10);

  /// Supabase-assigned result ID, set after successful save.
  String? _savedResultId;

  /// Guards against retry re-queuing the same result to SQLite.
  bool _resultQueued = false;
  StreamSubscription<WorkoutEngineState>? _engineSub;
  StreamSubscription<int>? _countdownBeepSub;
  StreamSubscription<PM5Data>? _pm5BleSubscription;
  StreamSubscription<int>? _hrBleSubscription;
  StreamSubscription<HrConnectionState>? _hrConnectionSub;
  StreamSubscription<PM5ConnectionState>? _pm5ConnectionSub;

  /// The latest standalone HR value for merging with PM5 data.
  int? _lastStandaloneHr;

  /// Recorded when start() is called — used for accurate startedAt.
  DateTime? _startedAt;

  /// IANA timezone captured at workout load time (e.g. "America/New_York").
  String _timezone = 'UTC';

  /// Generation counter to guard against concurrent loadWorkout calls.
  int _loadGeneration = 0;

  /// BLE data stream controller — feeds into the workout engine.
  final _pm5Controller = StreamController<PM5Data>.broadcast();

  @override
  WorkoutSessionState build() {
    // read (not watch): these are stable singletons. Watching them would
    // re-run build() on invalidation after _cleanup closed _pm5Controller,
    // leaving the new subscriptions feeding a closed controller.
    _supabaseService = ref.read(supabaseServiceProvider);
    _syncService = ref.read(syncServiceProvider);
    _workoutRepository = ref.read(workoutRepositoryProvider);
    _foregroundService = ref.read(foregroundSessionServiceProvider);
    _recoveryService = ref.read(sessionRecoveryServiceProvider);
    ref.onDispose(_cleanup);
    _subscribeToBle();
    return const WorkoutSessionState();
  }

  /// When true, incoming BLE data is ignored (during PM5 reset sequence).
  bool _suppressBleData = false;

  /// Subscribe to BLE PM5 data, standalone HR, and HR connection state.
  void _subscribeToBle() {
    // Listen to PM5 BLE data
    final pm5Stream = ref.read(pm5ServiceProvider).pm5DataStream;
    _pm5BleSubscription = pm5Stream.listen((pm5Data) {
      // Ignore stale data while PM5 is being reset
      if (_suppressBleData) return;

      // Merge standalone HR — prefer chest strap (more accurate)
      PM5Data merged = pm5Data;
      if (_lastStandaloneHr != null) {
        merged = pm5Data.copyWith(
          heartRate: _lastStandaloneHr,
          strokeRateUpdated: pm5Data.strokeRateUpdated,
        );
      }

      _pm5Controller.add(merged);
      state = state.copyWith(pm5Data: merged);
    });

    // Listen to standalone HR data
    final hrStream = ref.read(hrServiceProvider).heartRateStream;
    _hrBleSubscription = hrStream.listen((hr) {
      _lastStandaloneHr = hr;

      // If no PM5 data is flowing, still update the HR display
      if (state.pm5Data.heartRate != hr) {
        final updated = state.pm5Data.copyWith(heartRate: hr);
        state = state.copyWith(pm5Data: updated);
      }
    });

    // Clear stale HR and auto-reconnect when the HR monitor disconnects.
    // BleNotifier.autoReconnect runs a bounded backoff loop and ignores
    // reentrant calls, so no caller-side cooldown is needed.
    final hrService = ref.read(hrServiceProvider);
    _hrConnectionSub = hrService.connectionState.listen((connState) {
      if (connState == HrConnectionState.disconnected) {
        _lastStandaloneHr = null;
        // Only auto-reconnect on unexpected drops, not intentional disconnects.
        // Delay to let BleNotifier process the event first (subscription ordering).
        if (!hrService.intentionalDisconnect) {
          Future.microtask(
            () => ref.read(bleProvider.notifier).autoReconnect(),
          );
        }
      }
    });

    // Auto-reconnect PM5 if it disconnects mid-workout.
    // Delay to let BleNotifier process the event first (subscription ordering).
    final pm5Service = ref.read(pm5ServiceProvider);
    _pm5ConnectionSub = pm5Service.connectionState.listen((connState) {
      if (connState == PM5ConnectionState.disconnected &&
          !pm5Service.intentionalDisconnect) {
        Future.microtask(
          () => ref.read(bleProvider.notifier).autoReconnect(),
        );
      }
    });
  }

  /// Push PM5 data from BLE layer (kept for backward compatibility).
  void onPM5Data(PM5Data data) {
    _pm5Controller.add(data);
    state = state.copyWith(pm5Data: data);
  }

  /// Send CSAFE commands to fully reset the PM5 and clear any previous session.
  /// Uses the full state transition: goFinished → goIdle → reset → goReady.
  Future<void> _resetPm5() async {
    final pm5 = ref.read(pm5ServiceProvider);
    final deviceId = pm5.connectedDeviceId;
    if (deviceId == null) return;
    try {
      await pm5.sendCsafeCommand(CsafeCommands.goFinished(), deviceId);
      await Future.delayed(const Duration(milliseconds: 300));
      await pm5.sendCsafeCommand(CsafeCommands.goIdle(), deviceId);
      await Future.delayed(const Duration(milliseconds: 300));
      await pm5.sendCsafeCommand(CsafeCommands.reset(), deviceId);
      await Future.delayed(const Duration(milliseconds: 800));
      await pm5.sendCsafeCommand(CsafeCommands.goReady(), deviceId);
    } catch (e) {
      // Non-critical — PM5 may not respond if not connected
      AppLog.warn('workout', 'PM5 reset sequence failed', e);
    }
  }

  /// Load a workout definition and prepare the engine.
  Future<void> loadWorkout(
    String workoutId, {
    String? planId,
    int? planWeek,
    int? planSession,
  }) async {
    // Clean up previous engine before resetting state — prevents the old
    // engine's listener from overwriting the fresh state during async gaps.
    _engineSub?.cancel();
    _engineSub = null;
    _countdownBeepSub?.cancel();
    _countdownBeepSub = null;
    _engine?.dispose();
    _engine = null;
    _startedAt = null;
    _resultQueued = false;
    _savedResultId = null;
    _suppressBleData = true;
    _lastStandaloneHr = null;
    _lastSnapshotAt = null;
    _stopForegroundService();
    // A new load implicitly abandons any previous unsaved session.
    unawaited(_recoveryService.clear());
    try {
      _timezone = await FlutterTimezone.getLocalTimezone();
    } catch (e) {
      AppLog.warn('workout', 'Timezone lookup failed, defaulting to UTC', e);
      _timezone = 'UTC';
    }
    _loadGeneration++;
    final myGen = _loadGeneration;

    // Reset all state immediately so old workout data doesn't flash on screen.
    state = const WorkoutSessionState().copyWith(
      isLoading: true,
      planId: planId,
      planWeek: planWeek,
      planSession: planSession,
    );

    try {
      final workout = await _workoutRepository.getWorkout(workoutId);
      if (_loadGeneration != myGen) return; // Superseded by a newer load

      // Fetch user's profile for max HR, resting HR, zone system, FTP
      int? maxHr;
      int? restingHr;
      ZoneSystem zoneSystem = ZoneSystem.rowing;
      int ftpWatts = kDefaultFtpWatts;
      try {
        final profile = await _supabaseService.getProfile();
        maxHr = profile.maxHeartRate;
        restingHr = profile.restingHeartRate;
        zoneSystem = profile.zoneSystem;
        if (profile.currentFtpWatts != null && profile.currentFtpWatts! > 0) {
          ftpWatts = profile.currentFtpWatts!;
        }
      } catch (e) {
        // Non-critical — fall back to defaults
        AppLog.warn('workout', 'Profile fetch failed, using default zones/FTP', e);
      }
      if (_loadGeneration != myGen) return; // Superseded by a newer load

      final isRampTest = workout.tags.contains('ramp');
      _engine = WorkoutEngine(
        workout: workout,
        pm5Stream: _pm5Controller.stream,
        ftpWatts: ftpWatts,
        paceFailThreshold: isRampTest ? 10 : 0,
        autoPauseFinishSeconds: isRampTest ? 15 : 0,
      );

      _countdownBeepSub = _engine!.countdownBeepStream.listen((secondsLeft) {
        AudioService.instance.playCountdownBeep(secondsLeft);
      });

      _engineSub = _engine!.stateStream.listen((engineState) {
        final engine = _engine;
        if (engine == null) return;
        // Record start time on first transition into an active phase
        if (_startedAt == null &&
            (engineState.phase == WorkoutPhase.rowing ||
             engineState.phase == WorkoutPhase.resting)) {
          _startedAt = DateTime.now();
        }
        state = state.copyWith(
          engineState: engineState,
          timeSamples: engine.timeSamples,
        );

        // Keep the Android foreground service in step with the session so
        // BLE survives backgrounding, and periodically snapshot progress
        // for crash recovery.
        _syncForegroundService(engineState.phase);
        _maybeSnapshot(engineState.phase);

        // When engine finishes on its own (all segments complete or pace fail),
        // build the pending result so the summary screen appears.
        if (engineState.phase == WorkoutPhase.finished &&
            state.pendingResult == null) {
          _buildPendingResult();
        }
      });

      // Enter ready phase before flipping isLoading: false so the engine is
      // already armed when the START button becomes tappable. Otherwise a tap
      // during the ~2s PM5 reset window transitions idle→countingDown, then
      // the late ready() call clobbers it back to ready and the countdown
      // silently aborts. BLE is suppressed during reset (see _suppressBleData),
      // so the engine sees no frames until reset completes.
      _engine?.ready();

      state = state.copyWith(
        workoutTitle: workout.title,
        expandedSegments: _engine!.expandedSegments,
        workoutTags: workout.tags,
        maxHeartRate: maxHr,
        restingHeartRate: restingHr,
        zoneSystem: zoneSystem,
        ftpWatts: ftpWatts,
        isLoading: false,
      );

      // Reset PM5 to clear any previous session data and zero out display.
      // BLE data has been suppressed since the top of loadWorkout().
      try {
        await _resetPm5();
      } finally {
        _suppressBleData = false;
      }
      if (_loadGeneration != myGen) return; // Superseded during PM5 reset
      state = state.copyWith(pm5Data: const PM5Data.zero());
    } catch (e) {
      if (_loadGeneration != myGen) return;
      _suppressBleData = false;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load workout: $e',
      );
    }
  }

  /// Start the workout. Runs a 3-2-1 audible countdown before segment 1 so
  /// the rower can settle on the seat. First-stroke auto-start (detected via
  /// PM5) skips the countdown and begins segment 1 immediately.
  ///
  /// `_startedAt` is intentionally NOT set here — the engine listener stamps
  /// it on the first transition into rowing/resting (3s later, after the
  /// countdown completes). Setting it now would back-date the workout by the
  /// countdown duration, inflating `finishedAt - startedAt` vs PM5 elapsed
  /// time.
  void start() {
    _engine?.start(countdownSeconds: 3);
  }

  /// Pause the workout.
  void pause() {
    _engine?.pause();
  }

  /// Resume after pause.
  void resume() {
    _engine?.resume();
  }

  /// Continue with free row after structured workout completes.
  void continueWithFreeRow() {
    _engine?.continueWithFreeRow();
    // Update expanded segments since a new one was appended
    if (_engine != null) {
      state = state.copyWith(
        expandedSegments: _engine!.expandedSegments,
      );
    }
  }

  /// Finish from structuredComplete (user chose Save).
  void finishFromStructuredComplete() {
    _engine?.finishFromStructuredComplete();
    _buildPendingResult();
  }

  /// Stop the workout and build a pending result (does NOT save).
  Future<void> stop() async {
    if (_engine == null) return;
    _engine!.stop();
    // The engine listener will detect finished and call _buildPendingResult().
    // But if it already fired synchronously, this is a no-op (guarded by null check).
    _buildPendingResult();
  }

  /// Phases during which a workout session is considered live — the
  /// foreground service must be running to keep BLE alive.
  static bool _isSessionActive(WorkoutPhase phase) =>
      phase == WorkoutPhase.countingDown ||
      phase == WorkoutPhase.rowing ||
      phase == WorkoutPhase.paused ||
      phase == WorkoutPhase.resting ||
      phase == WorkoutPhase.structuredComplete;

  /// Start/stop the foreground service on session phase transitions.
  void _syncForegroundService(WorkoutPhase phase) {
    if (_isSessionActive(phase)) {
      if (!_foregroundServiceRunning) {
        _foregroundServiceRunning = true;
        unawaited(_foregroundService.start(workoutTitle: state.workoutTitle));
      }
    } else if (phase == WorkoutPhase.finished) {
      _stopForegroundService();
    }
  }

  void _stopForegroundService() {
    if (!_foregroundServiceRunning) return;
    _foregroundServiceRunning = false;
    unawaited(_foregroundService.stop());
  }

  /// Write a crash-recovery snapshot at most every [_snapshotInterval]
  /// while actively rowing/resting.
  void _maybeSnapshot(WorkoutPhase phase) {
    if (phase != WorkoutPhase.rowing && phase != WorkoutPhase.resting) return;
    final now = DateTime.now();
    if (_lastSnapshotAt != null &&
        now.difference(_lastSnapshotAt!) < _snapshotInterval) {
      return;
    }
    final result = _composeResult();
    if (result == null) return;
    _lastSnapshotAt = now;
    unawaited(_recoveryService.saveSnapshot(result));
  }

  /// Build WorkoutResult from engine data and store as pendingResult.
  /// Safe to call multiple times — no-ops if already built.
  void _buildPendingResult() {
    if (_engine == null || state.pendingResult != null) return;

    final result = _composeResult();
    if (result == null) return;

    state = state.copyWith(
      pendingResult: result,
      timeSamples: _engine!.timeSamples,
    );

    // Final snapshot — an app kill on the summary screen (before the user
    // taps Save) must still be recoverable.
    unawaited(_recoveryService.saveSnapshot(result));

    _detectFtpTest();
  }

  /// Compose a [WorkoutResult] from the current engine data, or null when
  /// there is nothing worth saving yet.
  WorkoutResult? _composeResult() {
    if (_engine == null) return null;

    final userId = _supabaseService.currentUserId;
    if (userId == null) return null;

    final now = DateTime.now();
    final data = state.pm5Data;
    final splits = _engine!.completedSplits;

    // Don't save empty results (stopped before any rowing at all)
    if (splits.isEmpty && data.distance == 0 && data.elapsedTime == Duration.zero) {
      return null;
    }

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
      workoutName: state.workoutTitle.isNotEmpty ? state.workoutTitle : null,
      startedAt: startedAt,
      finishedAt: now,
      totalDistance: data.distance,
      totalTime: data.elapsedTime,
      avgSplit: avgSplit,
      avgStrokeRate: avgSR,
      avgHeartRate: _engine!.currentState.avgHeartRate,
      minHeartRate: _engine!.overallMinHr,
      maxHeartRate: _engine!.overallMaxHr,
      endingHeartRate: _engine!.endingHeartRate,
      avgWatts: avgW,
      calories: data.calories,
      strokeCount: data.strokeCount,
      dragFactor: _engine!.avgDragFactor,
      timezone: _timezone,
      splits: splits,
      timeSamples: _engine!.timeSamples,
    );

    return result;
  }

  /// If this workout was an FTP test, compute the new FTP for the summary.
  void _detectFtpTest() {
    if (_engine == null) return;
    final splits = _engine!.completedSplits;
    final tags = state.workoutTags;
    if (tags.contains('ftp') && splits.isNotEmpty) {
      final isRamp = tags.contains('ramp');
      int ftp;
      String basis;
      final segments = _engine!.expandedSegments;

      int? rampStagesCompleted;
      int? rampTotalStages;
      int? rampPeakWatts;

      if (isRamp) {
        final rampResult = FtpCalculator.calculateRampFtp(splits, segments);
        ftp = rampResult.ftp;
        basis = '65% of ${rampResult.lastStageWatts}W stage';

        // Total work stages: 60s segments with a target (excludes 120s warmup).
        rampTotalStages = segments
            .where((s) => s.hasTarget && s.durationValue == 60)
            .length;
        rampStagesCompleted = rampResult.stagesCompleted;
        rampPeakWatts = rampResult.lastStageWatts;
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
          calculatedFtp: ftp,
          ftpCalculationBasis: basis,
          previousFtpWatts: state.ftpWatts,
          rampStagesCompleted: rampStagesCompleted,
          rampTotalStages: rampTotalStages,
          rampPeakWatts: rampPeakWatts,
        );
      }
    }
  }

  /// Save the pending result (queue for sync, record plan progress).
  /// If [ftpWatts] is provided, saves the FTP record after the result is
  /// persisted so that [sourceResultId] links the two correctly.
  /// Idempotent: retries sync existing rows instead of re-queuing.
  Future<void> saveResult({int? ftpWatts}) async {
    final result = state.pendingResult;
    if (result == null && !_resultQueued) return;

    state = state.copyWith(saveProgress: SaveProgress.saving);

    try {
      final SyncOutcome outcome;

      if (!_resultQueued) {
        // First attempt: queue to SQLite + attempt sync
        outcome = await _syncService.queueResult(result!);
        _resultQueued = true;
        _savedResultId = outcome.resultId;
        ref.invalidate(workoutHistoryProvider);

        // The result is safely queued in SQLite — the crash-recovery
        // snapshot is no longer needed.
        unawaited(_recoveryService.clear());

        // Record plan progress (once only)
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
            ref.invalidate(planProgressProvider(state.planId!));
            ref.invalidate(userPlanProgressProvider);
          } catch (e, st) {
            // Don't block workout completion, but surface it — the user's
            // plan won't show this session as done.
            AppLog.error('workout', 'Failed to record plan progress', e, st);
            state = state.copyWith(
              syncError: 'Workout saved, but plan progress could not be '
                  'recorded — it will not show as completed in your plan.',
            );
          }
        }

        // Save FTP after result ID is available
        if (ftpWatts != null && ftpWatts > 0) {
          try {
            await saveFtp(ftpWatts);
          } catch (e, st) {
            // Workout was already saved — surface the FTP failure.
            AppLog.error('workout', 'FTP save failed after workout save', e, st);
            state = state.copyWith(
              syncError: 'Workout saved, but your new FTP could not be '
                  'saved. You can set it manually in your profile.',
            );
          }
        }
      } else {
        // Retry: sync existing pending rows without re-queuing
        outcome = await _syncService.retrySync();
        if (outcome.resultId != null) {
          _savedResultId = outcome.resultId;
        }
      }

      state = state.copyWith(saveProgress: SaveProgress.savedLocally);

      // Cloud status from actual sync outcome
      if (outcome.savedToSupabase) {
        state = state.copyWith(saveProgress: SaveProgress.savedToCloud);

        // Check for new PRs and achievements after successful cloud save
        if (result != null && _savedResultId != null) {
          try {
            final prService = ref.read(prServiceProvider);
            final achievementService = ref.read(achievementServiceProvider);

            // Ensure services are loaded
            if (!prService.isLoaded) await prService.load();
            if (!achievementService.isLoaded) await achievementService.load();

            final prs =
                await prService.checkAndUpdatePRs(result, _savedResultId!);

            // Get cumulative stats for achievement checks
            final results =
                await ref.read(workoutHistoryProvider.future);
            final totalDistance =
                results.fold(0.0, (sum, r) => sum + r.totalDistance);
            final totalWorkouts = results.length;
            final completedPlanCount =
                await ref.read(completedPlanCountProvider.future);

            final achievements = await achievementService.checkAchievements(
              userId: result.userId,
              totalDistance: totalDistance,
              totalWorkouts: totalWorkouts,
              completedPlanCount: completedPlanCount,
              results: results,
              resultId: _savedResultId,
            );

            if (prs.isNotEmpty || achievements.isNotEmpty) {
              state = state.copyWith(
                newPRs: [...state.newPRs, ...prs],
                newAchievements: [...state.newAchievements, ...achievements],
              );
            }
          } catch (e, st) {
            // Non-critical — don't block save completion, but report it:
            // silently missing PRs/achievements erode trust in the stats.
            AppLog.error('workout', 'PR/achievement check failed', e, st);
          }
        }
      } else if (outcome.error != null) {
        state = state.copyWith(syncError: outcome.error);
      }

      // C2 Logbook status from actual sync outcome.
      // Not-linked is encoded as savedToC2: true (marked done) with no error.
      if (outcome.savedToC2 && outcome.error == null) {
        // Either synced successfully or user is not C2-linked
        final c2Service = ref.read(c2LogbookServiceProvider);
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
    } catch (e, st) {
      // The most important failure in the app — a finished workout that
      // could not be persisted. Always report and tell the user.
      AppLog.error('workout', 'Saving workout result failed', e, st);
      state = state.copyWith(
        saveProgress: SaveProgress.error,
        syncError: 'Saving failed: $e',
      );
    }
  }

  /// Discard the pending result without saving.
  void discardResult() {
    unawaited(_recoveryService.clear());
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

    // Check for FTP PR
    try {
      final prService = ref.read(prServiceProvider);
      if (!prService.isLoaded) await prService.load();
      final ftpPr = await prService.checkFtpPR(watts, userId, _savedResultId);
      if (ftpPr != null) {
        state = state.copyWith(newPRs: [...state.newPRs, ftpPr]);
      }
    } catch (e, st) {
      // Non-critical — the FTP itself was saved.
      AppLog.error('workout', 'FTP PR check failed', e, st);
    }
  }

  /// Registered via ref.onDispose in [build].
  void _cleanup() {
    _stopForegroundService();
    _engineSub?.cancel();
    _countdownBeepSub?.cancel();
    _engine?.dispose();
    _pm5Controller.close();
    _pm5BleSubscription?.cancel();
    _hrBleSubscription?.cancel();
    _hrConnectionSub?.cancel();
    _pm5ConnectionSub?.cancel();
  }
}

final workoutSessionProvider =
    NotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>(
        WorkoutSessionNotifier.new);
