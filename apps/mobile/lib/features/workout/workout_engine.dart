import 'dart:async';
import 'dart:math' as math;

import '../../models/pm5_data.dart';
import '../../models/workout.dart';
import '../../models/workout_segment.dart';
import '../../models/workout_result.dart';
import '../../models/workout_time_sample.dart';
import '../../utils/pace_utils.dart';

/// Phases of workout execution.
enum WorkoutPhase {
  idle,
  ready,
  countingDown,
  rowing,
  paused,
  resting,
  /// All structured segments done — UI shows completion modal.
  structuredComplete,
  finished,
}

/// Why the workout ended — normal completion or pace failure.
enum FinishReason {
  allSegmentsComplete,
  paceFailed,
  userStopped,
}

/// Immutable snapshot of the workout engine state.
class WorkoutEngineState {
  final WorkoutPhase phase;
  final int currentSegmentIndex;
  final WorkoutSegment? currentSegment;
  final double segmentProgress;
  final double segmentElapsedDistance;
  final Duration segmentElapsedTime;
  final int countdownSeconds;
  final PM5Data latestData;
  final bool isAutoPaused;
  final Duration pausedDuration;
  final int segmentElapsedCalories;

  /// How many consecutive seconds the rower has been outside the target
  /// pace window. Resets to 0 when back in range. Used by the UI to
  /// show a warning before auto-stop.
  final int secondsOutOfRange;

  /// The configured pace fail threshold (seconds). Used by the UI to
  /// compute the countdown display.
  final int paceFailThreshold;

  /// Seconds remaining before auto-pause triggers workout finish.
  /// 0 = not counting down. Used by ramp FTP tests.
  final int autoPauseCountdown;

  /// If the workout finished, why.
  final FinishReason? finishReason;

  /// Running averages across the workout.
  final int avgPace;
  final int? avgHeartRate;

  const WorkoutEngineState({
    this.phase = WorkoutPhase.idle,
    this.currentSegmentIndex = 0,
    this.currentSegment,
    this.segmentProgress = 0,
    this.segmentElapsedDistance = 0,
    this.segmentElapsedTime = Duration.zero,
    this.countdownSeconds = 0,
    this.latestData = const PM5Data.zero(),
    this.isAutoPaused = false,
    this.pausedDuration = Duration.zero,
    this.segmentElapsedCalories = 0,
    this.secondsOutOfRange = 0,
    this.paceFailThreshold = 10,
    this.autoPauseCountdown = 0,
    this.finishReason,
    this.avgPace = 0,
    this.avgHeartRate,
  });

  WorkoutEngineState copyWith({
    WorkoutPhase? phase,
    int? currentSegmentIndex,
    WorkoutSegment? currentSegment,
    double? segmentProgress,
    double? segmentElapsedDistance,
    Duration? segmentElapsedTime,
    int? countdownSeconds,
    PM5Data? latestData,
    bool? isAutoPaused,
    Duration? pausedDuration,
    int? segmentElapsedCalories,
    int? secondsOutOfRange,
    int? paceFailThreshold,
    int? autoPauseCountdown,
    FinishReason? finishReason,
    int? avgPace,
    int? avgHeartRate,
  }) {
    return WorkoutEngineState(
      phase: phase ?? this.phase,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      currentSegment: currentSegment ?? this.currentSegment,
      segmentProgress: segmentProgress ?? this.segmentProgress,
      segmentElapsedDistance:
          segmentElapsedDistance ?? this.segmentElapsedDistance,
      segmentElapsedTime: segmentElapsedTime ?? this.segmentElapsedTime,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      latestData: latestData ?? this.latestData,
      isAutoPaused: isAutoPaused ?? this.isAutoPaused,
      pausedDuration: pausedDuration ?? this.pausedDuration,
      segmentElapsedCalories:
          segmentElapsedCalories ?? this.segmentElapsedCalories,
      secondsOutOfRange: secondsOutOfRange ?? this.secondsOutOfRange,
      paceFailThreshold: paceFailThreshold ?? this.paceFailThreshold,
      autoPauseCountdown: autoPauseCountdown ?? this.autoPauseCountdown,
      finishReason: finishReason ?? this.finishReason,
      avgPace: avgPace ?? this.avgPace,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
    );
  }
}

/// Workout execution engine (state machine).
///
/// Takes a [Workout] definition and a stream of [PM5Data] from BLE,
/// manages interval transitions, and emits [WorkoutEngineState] updates.
///
/// For ramp/FTP tests: if the rower's pace exceeds the resolved target max
/// for [paceFailThreshold] consecutive seconds, the workout auto-finishes
/// with [FinishReason.paceFailed]. The UI can use [secondsOutOfRange] to
/// show a countdown warning before auto-stop.
class WorkoutEngine {
  final Workout workout;
  final Stream<PM5Data> pm5Stream;

  /// User's FTP in watts, used to resolve intensity targets to pace.
  final int ftpWatts;

  /// How many consecutive seconds outside target pace before auto-stop.
  /// Default: 10 seconds. Set to 0 to disable pace fail detection.
  final int paceFailThreshold;

  /// How many seconds of auto-pause before auto-finishing the workout.
  /// 0 = disabled. Used by ramp FTP tests (15s) so stopping rowing
  /// triggers test completion.
  final int autoPauseFinishSeconds;

  final _stateController = StreamController<WorkoutEngineState>.broadcast();
  StreamSubscription<PM5Data>? _pm5Subscription;
  Timer? _restTimer;

  /// Wall-clock ticker for rest segments — advances segmentProgress every
  /// second independently of PM5 data (which may freeze when rower stops).
  Timer? _restTickTimer;
  DateTime? _restStartWallTime;

  /// The list of segments to execute.
  late final List<WorkoutSegment> _expandedSegments;

  WorkoutEngineState _state = const WorkoutEngineState();

  // Accumulators for split data collection
  double _segmentStartDistance = 0;
  Duration _segmentStartTime = Duration.zero;
  int _paceSum = 0;
  int _strokeRateSum = 0;
  int _wattsSum = 0;
  int _hrSum = 0;
  int _hrCount = 0;
  int _sampleCount = 0;

  // Overall accumulators (across all segments)
  int _totalPaceSum = 0;
  int _totalSampleCount = 0;
  int _totalHrSum = 0;
  int _totalHrCount = 0;

  // Time-series data collection (running log across whole workout)
  final List<WorkoutTimeSample> _timeSamples = [];
  Duration? _lastSampleTime;

  // Pace fail tracking
  DateTime? _outOfRangeSince;

  // Auto-pause tracking
  int _lastStrokeCount = 0;
  DateTime? _lastActivityAt;
  Timer? _autoPauseTimer;
  DateTime? _pausedAt;
  Duration _totalPausedDuration = Duration.zero;
  WorkoutPhase? _prePausePhase;
  int _segmentStartCalories = 0;
  static const _autoPauseDelaySeconds = 5;

  // Auto-pause finish timer (ramp FTP tests)
  Timer? _autoPauseFinishTimer;

  final List<SplitData> _completedSplits = [];

  WorkoutEngine({
    required this.workout,
    required this.pm5Stream,
    this.ftpWatts = kDefaultFtpWatts,
    this.paceFailThreshold = 10,
    this.autoPauseFinishSeconds = 0,
  }) {
    _expandedSegments = List.from(workout.segments);
  }

  /// Stream of engine state updates.
  Stream<WorkoutEngineState> get stateStream => _stateController.stream;

  /// Current engine state.
  WorkoutEngineState get currentState => _state;

  /// The list of all segments.
  List<WorkoutSegment> get expandedSegments =>
      List.unmodifiable(_expandedSegments);

  /// All split data collected so far.
  List<SplitData> get completedSplits =>
      List.unmodifiable(_completedSplits);

  /// Time-series samples collected across the whole workout.
  List<WorkoutTimeSample> get timeSamples =>
      List.unmodifiable(_timeSamples);

  /// Enter the ready phase — listens for PM5 data and starts the workout
  /// automatically when the rower takes the first stroke.
  void ready() {
    if (_expandedSegments.isEmpty) return;

    _state = _state.copyWith(
      phase: WorkoutPhase.ready,
      currentSegmentIndex: 0,
      currentSegment: _expandedSegments[0],
      paceFailThreshold: paceFailThreshold,
    );
    _emit();

    // Subscribe to PM5 data so we can detect the first stroke
    _pm5Subscription?.cancel();
    _pm5Subscription = pm5Stream.listen(_onPM5Data);
  }

  /// Start the workout immediately (manual fallback).
  void start() {
    if (_expandedSegments.isEmpty) return;
    _pm5Subscription?.cancel();
    _beginSegment(0);
  }

  /// Pause the workout (manual).
  void pause() {
    if (_state.phase != WorkoutPhase.rowing &&
        _state.phase != WorkoutPhase.resting) {
      return;
    }
    _prePausePhase = _state.phase;
    _pausedAt = DateTime.now();
    // Cancel timers so they don't fire while paused
    _restTimer?.cancel();
    _restTickTimer?.cancel();
    _restTickTimer = null;
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _state = _state.copyWith(
      phase: WorkoutPhase.paused,
      isAutoPaused: false,
    );
    _emit();
  }

  /// Resume after pause.
  void resume() {
    if (_state.phase != WorkoutPhase.paused) return;
    _cancelAutoPauseFinishTimer();
    _accumulatePausedDuration();
    final restoredPhase = _prePausePhase ?? WorkoutPhase.rowing;
    _state = _state.copyWith(
      phase: restoredPhase,
      isAutoPaused: false,
      pausedDuration: _totalPausedDuration,
    );
    _prePausePhase = null;
    _emit();
    // Reset auto-pause state — timer starts on first positive stroke
    // (Branch 3 in _onPM5Data), same as segment start. This avoids
    // immediately re-pausing a rower who resumes then adjusts straps.
    if (restoredPhase == WorkoutPhase.rowing) {
      _lastActivityAt = null;
    }
    // Restart timers if resuming into a rest segment
    if (restoredPhase == WorkoutPhase.resting) {
      final segment = _state.currentSegment;
      if (segment != null && segment.durationType == DurationType.time) {
        // Wall-clock elapsed = total since segment start minus all paused time.
        // Use the tick-based elapsed from state (updated by _tickRest) if available,
        // otherwise fall back to PM5 elapsed.
        final wallElapsed = _restStartWallTime != null
            ? (DateTime.now().difference(_restStartWallTime!) - _totalPausedDuration)
            : ((_state.latestData.elapsedTime - _segmentStartTime) - _totalPausedDuration);
        final remainingSeconds =
            segment.durationValue.toInt() - wallElapsed.inSeconds;
        // Restart the tick timer
        _restTickTimer?.cancel();
        _restTickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickRest());
        if (remainingSeconds > 0) {
          _restTimer = Timer(
            Duration(seconds: remainingSeconds),
            () => _advanceToNextSegment(),
          );
        } else {
          _advanceToNextSegment();
        }
      }
    }
  }

  void _checkAutoPause() {
    if (_state.phase != WorkoutPhase.rowing) return;
    if (_lastActivityAt == null) return;
    final elapsed = DateTime.now().difference(_lastActivityAt!).inSeconds;
    if (elapsed >= _autoPauseDelaySeconds) {
      _autoPause();
    }
  }

  void _autoPause() {
    if (_state.phase != WorkoutPhase.rowing) return;
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _prePausePhase = _state.phase;
    _pausedAt = DateTime.now();
    _state = _state.copyWith(
      phase: WorkoutPhase.paused,
      isAutoPaused: true,
    );
    _emit();

    // Start auto-finish countdown for ramp FTP tests
    if (autoPauseFinishSeconds > 0) {
      _startAutoPauseFinishTimer();
    }
  }

  void _startAutoPauseFinishTimer() {
    _autoPauseFinishTimer?.cancel();
    var remaining = autoPauseFinishSeconds;
    _state = _state.copyWith(autoPauseCountdown: remaining);
    _emit();
    _autoPauseFinishTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        // Guard: if resumed before this tick fires, don't finish.
        if (_state.phase != WorkoutPhase.paused) {
          _autoPauseFinishTimer?.cancel();
          _autoPauseFinishTimer = null;
          return;
        }
        remaining--;
        if (remaining <= 0) {
          _autoPauseFinishTimer?.cancel();
          _autoPauseFinishTimer = null;
          // Auto-finish the workout
          _finishCurrentSegment();
          _state = _state.copyWith(
            phase: WorkoutPhase.finished,
            finishReason: FinishReason.paceFailed,
            autoPauseCountdown: 0,
          );
          _emit();
          _cleanup();
        } else {
          _state = _state.copyWith(autoPauseCountdown: remaining);
          _emit();
        }
      },
    );
  }

  void _cancelAutoPauseFinishTimer() {
    _autoPauseFinishTimer?.cancel();
    _autoPauseFinishTimer = null;
    if (_state.autoPauseCountdown > 0) {
      _state = _state.copyWith(autoPauseCountdown: 0);
      _emit();
    }
  }

  void _autoResume() {
    if (_state.phase != WorkoutPhase.paused) return;
    _cancelAutoPauseFinishTimer();
    _accumulatePausedDuration();
    _lastActivityAt = DateTime.now();
    _state = _state.copyWith(
      phase: _prePausePhase ?? WorkoutPhase.rowing,
      isAutoPaused: false,
      pausedDuration: _totalPausedDuration,
    );
    _prePausePhase = null;
    // Restart auto-pause timer
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _autoPauseTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkAutoPause(),
    );
    _emit();
  }

  /// Tick handler called every second during a timed rest segment.
  /// Advances segmentProgress from wall-clock time so the countdown display
  /// updates even when the PM5 stops sending data.
  void _tickRest() {
    if (_state.phase != WorkoutPhase.resting) return;
    final segment = _state.currentSegment;
    if (segment == null || segment.durationType != DurationType.time) return;
    if (_restStartWallTime == null) return;

    final wallElapsed = DateTime.now().difference(_restStartWallTime!) - _totalPausedDuration;
    final totalSec = segment.durationValue;
    final elapsed = wallElapsed.isNegative ? Duration.zero : wallElapsed;
    final progress = (elapsed.inSeconds / totalSec).clamp(0.0, 1.0);
    _state = _state.copyWith(
      segmentProgress: progress,
      segmentElapsedTime: elapsed,
    );
    _emit();
  }

  void _accumulatePausedDuration() {
    if (_pausedAt != null) {
      _totalPausedDuration += DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
    }
  }

  /// Continue with a free-row segment after structured workout completes.
  /// Appends a long free-row segment and re-enters rowing phase.
  void continueWithFreeRow() {
    if (_state.phase != WorkoutPhase.structuredComplete) return;
    const freeSegment = WorkoutSegment(
      durationType: DurationType.time,
      durationValue: 7200, // 2 hours max
      isRest: false,
    );
    _expandedSegments.add(freeSegment);
    _beginSegment(_expandedSegments.length - 1);
  }

  /// Finalize the workout from structuredComplete state.
  void finishFromStructuredComplete() {
    if (_state.phase != WorkoutPhase.structuredComplete) return;
    _state = _state.copyWith(
      phase: WorkoutPhase.finished,
      pausedDuration: _totalPausedDuration,
    );
    _emit();
    _cleanup();
  }

  /// Stop the workout and finalize results.
  void stop() {
    _accumulatePausedDuration();
    _finishCurrentSegment();
    _state = _state.copyWith(
      phase: WorkoutPhase.finished,
      finishReason: FinishReason.userStopped,
      pausedDuration: _totalPausedDuration,
    );
    _emit();
    _cleanup();
  }

  void _beginSegment(int index) {
    if (index >= _expandedSegments.length) {
      // All structured segments done — pause for user decision
      _state = _state.copyWith(
        phase: WorkoutPhase.structuredComplete,
        finishReason: FinishReason.allSegmentsComplete,
      );
      _emit();
      // Don't cleanup yet — user may choose to continue
      return;
    }

    final segment = _expandedSegments[index];
    final isRest = segment.isRest;

    // Reset accumulators
    _segmentStartDistance = _state.latestData.distance;
    _segmentStartTime = _state.latestData.elapsedTime;
    _segmentStartCalories = _state.latestData.calories;
    _paceSum = 0;
    _strokeRateSum = 0;
    _wattsSum = 0;
    _hrSum = 0;
    _hrCount = 0;
    _sampleCount = 0;
    _outOfRangeSince = null;
    _lastStrokeCount = _state.latestData.strokeCount;
    _lastActivityAt = null;
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _restTickTimer?.cancel();
    _restTickTimer = null;
    _restStartWallTime = null;
    _pausedAt = null;
    _totalPausedDuration = Duration.zero;
    _prePausePhase = null;

    _state = _state.copyWith(
      phase: isRest ? WorkoutPhase.resting : WorkoutPhase.rowing,
      currentSegmentIndex: index,
      currentSegment: segment,
      segmentProgress: 0,
      segmentElapsedDistance: 0,
      segmentElapsedTime: Duration.zero,
      segmentElapsedCalories: 0,
      secondsOutOfRange: 0,
      isAutoPaused: false,
      pausedDuration: Duration.zero,
    );
    _emit();

    // Start listening to PM5 data
    _pm5Subscription?.cancel();
    _pm5Subscription = pm5Stream.listen(_onPM5Data);

    // For rest segments with time duration, use a wall-clock timer (authoritative
    // advance) plus a 1Hz tick timer to keep the countdown display updated even
    // when PM5 stops sending data while the rower rests.
    if (isRest && segment.durationType == DurationType.time) {
      _restStartWallTime = DateTime.now();
      _restTickTimer?.cancel();
      _restTickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickRest());
      _restTimer?.cancel();
      _restTimer = Timer(
        Duration(seconds: segment.durationValue.toInt()),
        () => _advanceToNextSegment(),
      );
    }
  }

  void _onPM5Data(PM5Data data) {
    // ── Ready phase: wait for first stroke to start ──
    if (_state.phase == WorkoutPhase.ready) {
      _state = _state.copyWith(latestData: data);
      if (data.strokeRateUpdated && data.strokeRate > 0) {
        _pm5Subscription?.cancel();
        _beginSegment(0);
      } else {
        _emit();
      }
      return;
    }

    // ── Structured complete / finished — update display data only ──
    if (_state.phase == WorkoutPhase.structuredComplete ||
        _state.phase == WorkoutPhase.finished) {
      _state = _state.copyWith(latestData: data);
      _emit();
      return;
    }

    final segment = _state.currentSegment;
    if (segment == null) return;

    // ── Branch 1: Paused — update latestData, check for auto-resume ──
    if (_state.phase == WorkoutPhase.paused) {
      _state = _state.copyWith(latestData: data);
      if (data.strokeCount != _lastStrokeCount && _state.isAutoPaused) {
        _lastStrokeCount = data.strokeCount;
        _autoResume();
      } else {
        _emit();
      }
      return;
    }

    // ── Branch 2: Rowing with zero stroke rate — skip accumulation ──
    if (_state.phase == WorkoutPhase.rowing && data.strokeRate == 0) {
      // Auto-pause is handled by _autoPauseTimer checking _lastActivityAt.
      _state = _state.copyWith(latestData: data);
      _emit();
      return;
    }

    // ── Branch 3: Normal rowing (SR > 0) or resting ──
    // Detect actual new strokes via strokeCount (increments only on
    // completed strokes, unaffected by flywheel spin-down).
    if (data.strokeCount != _lastStrokeCount) {
      _lastStrokeCount = data.strokeCount;
      _lastActivityAt = DateTime.now();
      // Start auto-pause timer on first activity if not running
      if (_autoPauseTimer == null && _state.phase == WorkoutPhase.rowing) {
        _autoPauseTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _checkAutoPause(),
        );
      }
    }

    // Update latest data
    _state = _state.copyWith(latestData: data);

    // Accumulate for per-segment averages
    _sampleCount++;
    _paceSum += data.pace;
    _strokeRateSum += data.strokeRate;
    _wattsSum += data.watts;
    if (data.heartRate != null) {
      _hrSum += data.heartRate!;
      _hrCount++;
    }

    // Accumulate for overall averages
    _totalSampleCount++;
    _totalPaceSum += data.pace;
    if (data.heartRate != null) {
      _totalHrSum += data.heartRate!;
      _totalHrCount++;
    }

    // Collect time-series sample (~1/second, during rowing and resting)
    if (_state.phase == WorkoutPhase.rowing ||
        _state.phase == WorkoutPhase.resting) {
      final elapsed = data.elapsedTime;
      final shouldSample = _lastSampleTime == null ||
          (elapsed - _lastSampleTime!).inMilliseconds >= 1000;
      if (shouldSample) {
        _timeSamples.add(WorkoutTimeSample(
          timestamp: elapsed,
          pace: data.pace,
          strokeRate: data.strokeRate,
          heartRate: data.heartRate,
          segmentIndex: _state.currentSegmentIndex,
        ));
        _lastSampleTime = elapsed;
      }
    }

    // Calculate segment progress (clamp to >= 0 in case PM5 resets mid-segment)
    final elapsedDistance = math.max(0.0, data.distance - _segmentStartDistance);
    final elapsedTime = data.elapsedTime - _segmentStartTime;
    final elapsedCalories = math.max(0, data.calories - _segmentStartCalories);

    // For timed rest segments, _tickRest() owns segmentProgress/segmentElapsedTime
    // via wall-clock tracking. Skip PM5-derived progress here to avoid flickering
    // caused by competing writes (PM5 flywheel data vs wall-clock tick).
    final isTimedRest = _state.phase == WorkoutPhase.resting &&
        segment.durationType == DurationType.time;

    if (!isTimedRest) {
      double progress = 0;
      switch (segment.durationType) {
        case DurationType.distance:
          progress = elapsedDistance / segment.durationValue;
          break;
        case DurationType.time:
          // Subtract paused time so clock doesn't advance while paused
          final adjustedElapsed = elapsedTime - _totalPausedDuration;
          progress =
              adjustedElapsed.inSeconds / segment.durationValue;
          break;
        case DurationType.calories:
          progress = elapsedCalories / segment.durationValue;
          break;
      }
      progress = progress.clamp(0.0, 1.0);

      _state = _state.copyWith(
        segmentProgress: progress,
        segmentElapsedDistance: elapsedDistance,
        segmentElapsedTime: elapsedTime,
        segmentElapsedCalories: elapsedCalories,
      );
    } else {
      // Still track distance and calories during rest (e.g. for non-time rest types
      // and sample accumulation), but leave segmentProgress/segmentElapsedTime to _tickRest.
      _state = _state.copyWith(
        segmentElapsedDistance: elapsedDistance,
        segmentElapsedCalories: elapsedCalories,
      );
    }

    // ── Pace fail detection ────────────────────────────────────────────
    // For work segments with a pace target (intensity% or absolute watts),
    // check if the rower's pace exceeds the slowest acceptable pace.
    // Higher pace number = slower rowing.
    // After [paceFailThreshold] consecutive seconds outside range,
    // auto-finish the workout (used for ramp/FTP tests).
    final segmentTargetPace = resolveSegmentTargetPace(segment, ftpWatts);
    if (paceFailThreshold > 0 &&
        segmentTargetPace > 0 &&
        data.pace > 0) {
      final targetPace = segmentTargetPace;

      if (data.pace > targetPace) {
        // Rower is too slow — start or continue the fail timer
        _outOfRangeSince ??= DateTime.now();
        final secondsOut =
            DateTime.now().difference(_outOfRangeSince!).inSeconds;
        _state = _state.copyWith(secondsOutOfRange: secondsOut);

        if (secondsOut >= paceFailThreshold) {
          // Auto-stop: rower couldn't hold the pace
          _finishCurrentSegment();
          _state = _state.copyWith(
            phase: WorkoutPhase.finished,
            finishReason: FinishReason.paceFailed,
          );
          _emit();
          _cleanup();
          return;
        }
      } else {
        // Back in range — reset the fail timer
        _outOfRangeSince = null;
        _state = _state.copyWith(secondsOutOfRange: 0);
      }
    }

    _emit();

    // Check if segment is complete. Timed rest segments are advanced by
    // _restTimer, not by PM5 data — skip the check to avoid double-advance.
    if (!isTimedRest && _state.segmentProgress >= 1.0) {
      _advanceToNextSegment();
    }
  }

  bool _advancing = false;

  void _advanceToNextSegment() {
    // Guard against double-advance from both timer and PM5 data
    if (_advancing) return;
    _advancing = true;
    try {
      _restTimer?.cancel();
      _finishCurrentSegment();
      _beginSegment(_state.currentSegmentIndex + 1);
    } finally {
      _advancing = false;
    }
  }

  void _finishCurrentSegment() {
    // Always record a split when advancing normally between segments so
    // averages from zero-sample rest segments don't silently drop data.
    // When sampleCount is 0 (e.g. resting with no PM5 frames), use safe
    // zero/null values — a split with no data is better than a missing split.
    final split = SplitData(
      intervalIndex: _state.currentSegmentIndex,
      distance: math.max(0.0, _state.segmentElapsedDistance),
      time: _state.segmentElapsedTime,
      avgPace: _sampleCount > 0 ? _paceSum ~/ _sampleCount : 0,
      avgStrokeRate: _sampleCount > 0 ? _strokeRateSum ~/ _sampleCount : 0,
      avgWatts: _sampleCount > 0 ? _wattsSum ~/ _sampleCount : 0,
      avgHeartRate: _hrCount > 0 ? _hrSum ~/ _hrCount : null,
      calories: math.max(0, _state.latestData.calories - _segmentStartCalories),
    );
    _completedSplits.add(split);
  }

  void _emit() {
    _state = _state.copyWith(
      avgPace: _totalSampleCount > 0 ? _totalPaceSum ~/ _totalSampleCount : 0,
      avgHeartRate:
          _totalHrCount > 0 ? _totalHrSum ~/ _totalHrCount : null,
    );
    _stateController.add(_state);
  }

  void _cleanup() {
    _pm5Subscription?.cancel();
    _restTimer?.cancel();
    _restTickTimer?.cancel();
    _restTickTimer = null;
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _autoPauseFinishTimer?.cancel();
    _autoPauseFinishTimer = null;
  }

  /// Dispose all resources.
  void dispose() {
    _cleanup();
    _stateController.close();
  }
}
