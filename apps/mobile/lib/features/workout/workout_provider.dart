import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
import '../../services/pr_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../services/workout_repository.dart';
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

class WorkoutSessionNotifier extends StateNotifier<WorkoutSessionState> {
  final SupabaseService _supabaseService;
  final SyncService _syncService;
  final WorkoutRepository _workoutRepository;
  final Ref _ref;

  WorkoutEngine? _engine;

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
  DateTime? _lastPm5ReconnectAttempt;
  DateTime? _lastHrReconnectAttempt;

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

  WorkoutSessionNotifier(
    this._supabaseService,
    this._syncService,
    this._workoutRepository,
    this._ref,
  ) : super(const WorkoutSessionState()) {
    _subscribeToBle();
  }

  /// When true, incoming BLE data is ignored (during PM5 reset sequence).
  bool _suppressBleData = false;

  /// Subscribe to BLE PM5 data, standalone HR, and HR connection state.
  void _subscribeToBle() {
    // Listen to PM5 BLE data
    final pm5Stream = _ref.read(pm5ServiceProvider).pm5DataStream;
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
    final hrStream = _ref.read(hrServiceProvider).heartRateStream;
    _hrBleSubscription = hrStream.listen((hr) {
      _lastStandaloneHr = hr;

      // If no PM5 data is flowing, still update the HR display
      if (state.pm5Data.heartRate != hr) {
        final updated = state.pm5Data.copyWith(heartRate: hr);
        state = state.copyWith(pm5Data: updated);
      }
    });

    // Clear stale HR and auto-reconnect when the HR monitor disconnects
    final hrService = _ref.read(hrServiceProvider);
    _hrConnectionSub = hrService.connectionState.listen((connState) {
      if (connState == HrConnectionState.disconnected) {
        _lastStandaloneHr = null;
        // Only auto-reconnect on unexpected drops, not intentional disconnects.
        // Delay to let BleNotifier process the event first (subscription ordering).
        if (!hrService.intentionalDisconnect) {
          Future.microtask(() {
            final now = DateTime.now();
            final cooldown = _lastHrReconnectAttempt == null ||
                now.difference(_lastHrReconnectAttempt!).inSeconds >= 10;
            if (cooldown) {
              _lastHrReconnectAttempt = now;
              _ref.read(bleProvider.notifier).autoReconnect();
            }
          });
        }
      }
    });

    // Auto-reconnect PM5 if it disconnects mid-workout (with cooldown).
    // Delay to let BleNotifier process the event first (subscription ordering).
    final pm5Service = _ref.read(pm5ServiceProvider);
    _pm5ConnectionSub = pm5Service.connectionState.listen((connState) {
      if (connState == PM5ConnectionState.disconnected &&
          !pm5Service.intentionalDisconnect) {
        Future.microtask(() {
          final now = DateTime.now();
          final cooldown = _lastPm5ReconnectAttempt == null ||
              now.difference(_lastPm5ReconnectAttempt!).inSeconds >= 10;
          if (cooldown) {
            _lastPm5ReconnectAttempt = now;
            _ref.read(bleProvider.notifier).autoReconnect();
          }
        });
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
    final pm5 = _ref.read(pm5ServiceProvider);
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
    } catch (_) {
      // Non-critical — PM5 may not respond if not connected
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
    _timezone = await FlutterTimezone.getLocalTimezone();
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

      // Fetch user's profile for max HR and FTP (non-blocking on failure)
      int? maxHr;
      int ftpWatts = kDefaultFtpWatts;
      try {
        final profile = await _supabaseService.getProfile();
        maxHr = profile.maxHeartRate;
        if (profile.currentFtpWatts != null && profile.currentFtpWatts! > 0) {
          ftpWatts = profile.currentFtpWatts!;
        }
      } catch (_) {
        // Non-critical — fall back to defaults
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

      // Enter ready phase — workout starts when rower takes first stroke
      _engine?.ready();
    } catch (e) {
      if (_loadGeneration != myGen) return;
      _suppressBleData = false;
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

  /// Build WorkoutResult from engine data and store as pendingResult.
  /// Safe to call multiple times — no-ops if already built.
  void _buildPendingResult() {
    if (_engine == null || state.pendingResult != null) return;

    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final now = DateTime.now();
    final data = state.pm5Data;
    final splits = _engine!.completedSplits;

    // Don't save empty results (stopped before any rowing at all)
    if (splits.isEmpty && data.distance == 0 && data.elapsedTime == Duration.zero) return;

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
      avgHeartRate: data.heartRate,
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
        _ref.invalidate(workoutHistoryProvider);

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
            _ref.invalidate(planProgressProvider(state.planId!));
            _ref.invalidate(userPlanProgressProvider);
          } catch (_) {
            // Non-critical — don't block workout completion
          }
        }

        // Save FTP after result ID is available
        if (ftpWatts != null && ftpWatts > 0) {
          try {
            await saveFtp(ftpWatts);
          } catch (_) {
            // FTP save failed — workout was already saved
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
            final prService = _ref.read(prServiceProvider);
            final achievementService = _ref.read(achievementServiceProvider);

            // Ensure services are loaded
            if (!prService.isLoaded) await prService.load();
            if (!achievementService.isLoaded) await achievementService.load();

            final prs =
                await prService.checkAndUpdatePRs(result, _savedResultId!);

            // Get cumulative stats for achievement checks
            final results =
                await _ref.read(workoutHistoryProvider.future);
            final totalDistance =
                results.fold(0.0, (sum, r) => sum + r.totalDistance);
            final totalWorkouts = results.length;
            final completedPlanCount =
                await _ref.read(completedPlanCountProvider.future);

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
          } catch (_) {
            // Non-critical — don't block save completion
          }
        }
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

    // Check for FTP PR
    try {
      final prService = _ref.read(prServiceProvider);
      if (!prService.isLoaded) await prService.load();
      final ftpPr = await prService.checkFtpPR(watts, userId, _savedResultId);
      if (ftpPr != null) {
        state = state.copyWith(newPRs: [...state.newPRs, ftpPr]);
      }
    } catch (_) {
      // Non-critical
    }
  }

  @override
  void dispose() {
    _engineSub?.cancel();
    _countdownBeepSub?.cancel();
    _engine?.dispose();
    _pm5Controller.close();
    _pm5BleSubscription?.cancel();
    _hrBleSubscription?.cancel();
    _hrConnectionSub?.cancel();
    _pm5ConnectionSub?.cancel();
    super.dispose();
  }
}

final workoutSessionProvider =
    StateNotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>((ref) {
  return WorkoutSessionNotifier(
    ref.watch(supabaseServiceProvider),
    ref.watch(syncServiceProvider),
    ref.watch(workoutRepositoryProvider),
    ref,
  );
});
