import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';

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

/// Calculate the auto-split distance for a given total workout distance.
///
/// Matches PM5 behavior:
/// - 2000m → 500m splits (4 splits, C2 documented exception)
/// - 42195m (marathon) → 2000m splits (~21 splits, C2 documented exception)
/// - All others → total / 5 (fifths rule)
///
/// Returns 0 if auto-splitting does not apply (e.g. distance <= 0).
int autoSplitDistance(double totalDistance) {
  if (totalDistance <= 0) return 0;
  final total = totalDistance.round();
  // C2 documented exceptions
  if (total == 2000) return 500;
  if (total == 42195) return 2000;
  // General fifths rule
  return total ~/ 5;
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
  final _countdownBeepController = StreamController<int>.broadcast();
  StreamSubscription<PM5Data>? _pm5Subscription;
  Timer? _restTimer;

  /// Wall-clock ticker for rest segments — advances segmentProgress every
  /// second independently of PM5 data (which may freeze when rower stops).
  Timer? _restTickTimer;
  DateTime? _restStartWallTime;

  /// Wall-clock ticker for timed work segments — same approach as rest to
  /// avoid PM5 timer drift during pause/resume cycles.
  Timer? _workTickTimer;
  Timer? _workCompletionTimer;
  DateTime? _workStartWallTime;

  Timer? _countdownBeepTimer;
  DateTime? _segmentWallStart;
  int _countdownBeepsRemaining = -1;

  /// The list of segments to execute.
  late final List<WorkoutSegment> _expandedSegments;

  /// True when the workout has exactly one non-rest segment (candidate for auto-splitting).
  late bool _isSingleWorkSegment;

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
  int? _segmentMinHr;
  int? _segmentMaxHr;

  // Overall accumulators (across all segments)
  int _totalPaceSum = 0;
  int _totalSampleCount = 0;
  int _totalHrSum = 0;
  int _totalHrCount = 0;
  int? _overallMinHr;
  int? _overallMaxHr;
  int? _lastValidHr;

  // Drag factor accumulator
  int _dragFactorSum = 0;
  int _dragFactorCount = 0;

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

  static int _trackMin(int? current, int value) =>
      current == null ? value : math.min(current, value);

  static int _trackMax(int? current, int value) =>
      current == null ? value : math.max(current, value);

  // Auto-pause finish timer (ramp FTP tests)
  Timer? _autoPauseFinishTimer;

  final List<SplitData> _completedSplits = [];

  // Auto-split tracking for single-segment distance workouts
  bool _autoSplitEnabled = false;
  int _autoSplitDist = 0;
  double _nextAutoSplitThreshold = 0;
  // Per-auto-split accumulators (separate from segment accumulators)
  int _splitPaceSum = 0;
  int _splitSampleCount = 0;
  int _splitSRSum = 0;
  int _splitWattsSum = 0;
  int _splitHrSum = 0;
  int _splitHrCount = 0;
  int? _splitMinHr;
  int? _splitMaxHr;
  int _splitStartCalories = 0;
  double _splitStartDistance = 0;
  DateTime? _splitStartTime;
  Duration _splitPausedDuration = Duration.zero;
  DateTime? _splitPauseStart;

  WorkoutEngine({
    required this.workout,
    required this.pm5Stream,
    this.ftpWatts = kDefaultFtpWatts,
    this.paceFailThreshold = 10,
    this.autoPauseFinishSeconds = 0,
  }) {
    _expandedSegments = List.from(workout.segments);
    _isSingleWorkSegment =
        _expandedSegments.where((s) => !s.isRest).length == 1;
  }

  /// Stream of engine state updates.
  Stream<WorkoutEngineState> get stateStream => _stateController.stream;

  /// Emits secondsLeft (3, 2, 1, 0) for countdown beeps before segment end.
  /// Driven by wall-clock timers, independent of PM5 data and UI rebuilds.
  Stream<int> get countdownBeepStream => _countdownBeepController.stream;

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

  /// Overall HR min/max/ending across the entire workout.
  int? get overallMinHr => _overallMinHr;
  int? get overallMaxHr => _overallMaxHr;
  int? get endingHeartRate => _lastValidHr;

  /// Average drag factor across the workout, or null if none recorded.
  int? get avgDragFactor =>
      _dragFactorCount > 0 ? _dragFactorSum ~/ _dragFactorCount : null;

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
    _pausedAt = clock.now();
    if (_autoSplitEnabled) _splitPauseStart = clock.now();
    // Cancel timers so they don't fire while paused
    _restTimer?.cancel();
    _restTickTimer?.cancel();
    _restTickTimer = null;
    _workTickTimer?.cancel();
    _workTickTimer = null;
    _workCompletionTimer?.cancel();
    _workCompletionTimer = null;
    _cancelCountdownBeeps();
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
    // Restart timers if resuming into a timed segment
    final segment = _state.currentSegment;
    if (segment != null && segment.durationType == DurationType.time) {
      if (restoredPhase == WorkoutPhase.resting) {
        // Wall-clock elapsed = total since segment start minus all paused time.
        final wallElapsed = _restStartWallTime != null
            ? (clock.now().difference(_restStartWallTime!) - _totalPausedDuration)
            : ((_state.latestData.elapsedTime - _segmentStartTime) - _totalPausedDuration);
        final remainingSeconds =
            segment.durationValue.toInt() - wallElapsed.inSeconds;
        // Restart the tick timer
        _restTickTimer?.cancel();
        _restTickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickTimedSegment(WorkoutPhase.resting, _restStartWallTime));
        if (remainingSeconds > 0) {
          _restTimer = Timer(
            Duration(seconds: remainingSeconds),
            () => _advanceToNextSegment(),
          );
        } else {
          _advanceToNextSegment();
        }
      } else if (restoredPhase == WorkoutPhase.rowing && _workStartWallTime != null) {
        _restartWorkTimers();
      }
    }
    // Reschedule countdown beeps for both work and rest segments
    _rescheduleCountdownBeeps();
  }

  void _checkAutoPause() {
    if (_state.phase != WorkoutPhase.rowing) return;
    if (_lastActivityAt == null) return;
    final elapsed = clock.now().difference(_lastActivityAt!).inSeconds;
    if (elapsed >= _autoPauseDelaySeconds) {
      _autoPause();
    }
  }

  void _autoPause() {
    if (_state.phase != WorkoutPhase.rowing) return;
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _workTickTimer?.cancel();
    _workTickTimer = null;
    _workCompletionTimer?.cancel();
    _workCompletionTimer = null;
    _cancelCountdownBeeps();
    _prePausePhase = _state.phase;
    _pausedAt = clock.now();
    if (_autoSplitEnabled) _splitPauseStart = clock.now();
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
    _lastActivityAt = clock.now();
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
    // Restart work timers if auto-resuming into a timed work segment
    if (_state.phase == WorkoutPhase.rowing && _workStartWallTime != null) {
      _restartWorkTimers();
    }
    _rescheduleCountdownBeeps();
    _emit();
  }

  /// Tick handler called every second during a timed segment (work or rest).
  /// Advances segmentProgress from wall-clock time so the countdown display
  /// updates even when the PM5 stops sending data or drifts during pause.
  void _tickTimedSegment(WorkoutPhase expectedPhase, DateTime? wallStart) {
    if (_state.phase != expectedPhase) return;
    final segment = _state.currentSegment;
    if (segment == null || segment.durationType != DurationType.time) return;
    if (wallStart == null) return;

    final wallElapsed = clock.now().difference(wallStart) - _totalPausedDuration;
    final totalSec = segment.durationValue;
    final elapsed = wallElapsed.isNegative ? Duration.zero : wallElapsed;
    final progress = (elapsed.inSeconds / totalSec).clamp(0.0, 1.0);
    _state = _state.copyWith(
      segmentProgress: progress,
      segmentElapsedTime: elapsed,
    );
    _emit();
  }

  /// Restart wall-clock timers for a timed work segment after pause/resume.
  /// Calculates remaining time and starts both the tick and completion timers.
  void _restartWorkTimers() {
    final segment = _state.currentSegment;
    if (segment == null ||
        segment.durationType != DurationType.time ||
        _workStartWallTime == null) {
      return;
    }

    final wallElapsed =
        clock.now().difference(_workStartWallTime!) - _totalPausedDuration;
    final remainingSeconds =
        segment.durationValue.toInt() - wallElapsed.inSeconds;
    _workTickTimer?.cancel();
    _workTickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickTimedSegment(WorkoutPhase.rowing, _workStartWallTime),
    );
    if (remainingSeconds > 0) {
      _workCompletionTimer?.cancel();
      _workCompletionTimer = Timer(
        Duration(seconds: remainingSeconds),
        () => _advanceToNextSegment(),
      );
    } else {
      _advanceToNextSegment();
    }
  }

  void _scheduleCountdownBeeps(WorkoutSegment segment) {
    if (segment.durationType != DurationType.time) return;
    final totalSeconds = segment.durationValue.toInt();
    if (totalSeconds < 4) return; // Too short for a 3-second countdown

    _segmentWallStart = clock.now();
    final delayToFirstBeep = totalSeconds - 3;
    _countdownBeepsRemaining = 3;
    _countdownBeepTimer = Timer(
      Duration(seconds: delayToFirstBeep),
      _tickCountdownBeep,
    );
  }

  void _tickCountdownBeep() {
    if (_countdownBeepController.isClosed) return;
    if (_state.phase == WorkoutPhase.paused ||
        _state.phase == WorkoutPhase.finished ||
        _state.phase == WorkoutPhase.structuredComplete) {
      return;
    }
    final secondsLeft = _countdownBeepsRemaining;
    _countdownBeepController.add(secondsLeft);
    _countdownBeepsRemaining--;
    if (secondsLeft > 0) {
      _countdownBeepTimer = Timer(
        const Duration(seconds: 1),
        _tickCountdownBeep,
      );
    } else {
      _countdownBeepTimer = null;
    }
  }

  void _cancelCountdownBeeps() {
    _countdownBeepTimer?.cancel();
    _countdownBeepTimer = null;
    _countdownBeepsRemaining = -1;
  }

  void _rescheduleCountdownBeeps() {
    _cancelCountdownBeeps();
    final segment = _state.currentSegment;
    if (segment == null || segment.durationType != DurationType.time) return;
    if (_segmentWallStart == null) return;

    final totalSeconds = segment.durationValue.toInt();
    if (totalSeconds < 4) return;

    final wallElapsed =
        clock.now().difference(_segmentWallStart!) - _totalPausedDuration;
    final elapsedSeconds = wallElapsed.inSeconds;
    final remaining = totalSeconds - elapsedSeconds;

    if (remaining <= 0) return; // Segment is done
    if (remaining <= 3) {
      // Already in countdown window — start beeping immediately
      _countdownBeepsRemaining = remaining;
      _tickCountdownBeep();
    } else {
      // Schedule the first beep
      _countdownBeepsRemaining = 3;
      _countdownBeepTimer = Timer(
        Duration(seconds: remaining - 3),
        _tickCountdownBeep,
      );
    }
  }

  void _accumulatePausedDuration() {
    if (_pausedAt != null) {
      final now = clock.now();
      _totalPausedDuration += now.difference(_pausedAt!);
      _pausedAt = null;
      if (_autoSplitEnabled && _splitPauseStart != null) {
        _splitPausedDuration += now.difference(_splitPauseStart!);
        _splitPauseStart = null;
      }
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
    _isSingleWorkSegment = false; // No longer a single-segment workout
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
    _segmentMinHr = null;
    _segmentMaxHr = null;
    _outOfRangeSince = null;
    _lastStrokeCount = _state.latestData.strokeCount;
    _lastActivityAt = null;
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _restTickTimer?.cancel();
    _restTickTimer = null;
    _restStartWallTime = null;
    _workTickTimer?.cancel();
    _workTickTimer = null;
    _workCompletionTimer?.cancel();
    _workCompletionTimer = null;
    _workStartWallTime = null;
    _cancelCountdownBeeps();
    _segmentWallStart = null;
    _pausedAt = null;
    _totalPausedDuration = Duration.zero;
    _prePausePhase = null;

    // Determine if auto-splitting applies: single non-rest distance segment
    _autoSplitEnabled = false;
    _autoSplitDist = 0;
    if (!isRest &&
        segment.durationType == DurationType.distance &&
        _isSingleWorkSegment) {
      _autoSplitDist = autoSplitDistance(segment.durationValue);
      if (_autoSplitDist > 0 && _autoSplitDist < segment.durationValue) {
        _autoSplitEnabled = true;
        _nextAutoSplitThreshold = _autoSplitDist.toDouble();
        _resetAutoSplitAccumulators();
      }
    }

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
      _restStartWallTime = clock.now();
      _restTickTimer?.cancel();
      _restTickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickTimedSegment(WorkoutPhase.resting, _restStartWallTime));
      _restTimer?.cancel();
      _restTimer = Timer(
        Duration(seconds: segment.durationValue.toInt()),
        () => _advanceToNextSegment(),
      );
    }

    // For timed work segments, use wall-clock tracking (same as rest) to avoid
    // PM5 timer drift during pause/resume. The PM5 hardware timer keeps running
    // when the app pauses, causing countdown beeps and segment completion to
    // fire at wrong times.
    if (!isRest && segment.durationType == DurationType.time) {
      _workStartWallTime = clock.now();
      _workTickTimer?.cancel();
      _workTickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickTimedSegment(WorkoutPhase.rowing, _workStartWallTime));
      _workCompletionTimer?.cancel();
      _workCompletionTimer = Timer(
        Duration(seconds: segment.durationValue.toInt()),
        () => _advanceToNextSegment(),
      );
    }

    // Schedule countdown beeps for time-based segments (both work and rest).
    // Uses wall-clock timer so beeps fire reliably regardless of PM5 data.
    _scheduleCountdownBeeps(segment);
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
      _lastActivityAt = clock.now();
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
      final hr = data.heartRate!;
      _hrSum += hr;
      _hrCount++;
      _segmentMinHr = _trackMin(_segmentMinHr, hr);
      _segmentMaxHr = _trackMax(_segmentMaxHr, hr);
      _totalHrSum += hr;
      _totalHrCount++;
      _overallMinHr = _trackMin(_overallMinHr, hr);
      _overallMaxHr = _trackMax(_overallMaxHr, hr);
      _lastValidHr = hr;
    }

    // Accumulate drag factor (only during rowing — rest sends stale values)
    if (data.dragFactor > 0 && _state.phase == WorkoutPhase.rowing) {
      _dragFactorSum += data.dragFactor;
      _dragFactorCount++;
    }

    // Accumulate for auto-split averages
    if (_autoSplitEnabled) {
      _splitSampleCount++;
      _splitPaceSum += data.pace;
      _splitSRSum += data.strokeRate;
      _splitWattsSum += data.watts;
      if (data.heartRate != null) {
        final hr = data.heartRate!;
        _splitHrSum += hr;
        _splitHrCount++;
        _splitMinHr = _trackMin(_splitMinHr, hr);
        _splitMaxHr = _trackMax(_splitMaxHr, hr);
      }
    }

    // Accumulate for overall averages
    _totalSampleCount++;
    _totalPaceSum += data.pace;

    // Collect time-series sample (~1/second, during rowing and resting)
    if (_state.phase == WorkoutPhase.rowing ||
        _state.phase == WorkoutPhase.resting) {
      final elapsed = data.elapsedTime;
      final shouldSample = _lastSampleTime == null ||
          (elapsed - _lastSampleTime!).inMilliseconds >= 1000;
      if (shouldSample) {
        _timeSamples.add(WorkoutTimeSample(
          timestamp: elapsed,
          distance: data.distance,
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

    // For timed segments (both rest and work), wall-clock tick handlers own
    // segmentProgress/segmentElapsedTime. Skip PM5-derived progress here to
    // avoid flickering and drift from PM5 hardware timer during pause/resume.
    final isTimedRest = _state.phase == WorkoutPhase.resting &&
        segment.durationType == DurationType.time;
    final isTimedWork = _state.phase == WorkoutPhase.rowing &&
        segment.durationType == DurationType.time &&
        _workStartWallTime != null;

    if (!isTimedRest && !isTimedWork) {
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
      // Wall-clock tick owns segmentProgress/segmentElapsedTime — still track
      // distance and calories from PM5 data.
      _state = _state.copyWith(
        segmentElapsedDistance: elapsedDistance,
        segmentElapsedCalories: elapsedCalories,
      );
    }

    // ── Auto-split threshold detection ──────────────────────────────────
    // Loop to handle PM5 data that jumps past multiple thresholds at once.
    while (_autoSplitEnabled &&
        elapsedDistance >= _nextAutoSplitThreshold) {
      _snapshotAutoSplit(_autoSplitDist.toDouble());
      _nextAutoSplitThreshold += _autoSplitDist;
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
        _outOfRangeSince ??= clock.now();
        final secondsOut =
            clock.now().difference(_outOfRangeSince!).inSeconds;
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

    // Check if segment is complete. Timed segments (rest via _restTimer,
    // work via _workCompletionTimer) are advanced by wall-clock timers —
    // skip the check to avoid double-advance.
    if (!isTimedRest && !isTimedWork && _state.segmentProgress >= 1.0) {
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
      _workCompletionTimer?.cancel();
      _workTickTimer?.cancel();
      _workTickTimer = null;
      // Fire T-0 beep if we're waiting for exactly the final tick.
      if (_countdownBeepsRemaining == 0 &&
          _countdownBeepTimer != null &&
          !_countdownBeepController.isClosed) {
        _countdownBeepController.add(0);
      }
      _cancelCountdownBeeps();
      _finishCurrentSegment();
      _beginSegment(_state.currentSegmentIndex + 1);
    } finally {
      _advancing = false;
    }
  }

  void _resetAutoSplitAccumulators() {
    _splitPaceSum = 0;
    _splitSampleCount = 0;
    _splitSRSum = 0;
    _splitWattsSum = 0;
    _splitHrSum = 0;
    _splitHrCount = 0;
    _splitMinHr = null;
    _splitMaxHr = null;
    _splitStartCalories = _state.latestData.calories;
    _splitStartDistance = _state.latestData.distance - _segmentStartDistance;
    _splitStartTime = clock.now();
    _splitPausedDuration = Duration.zero;
    _splitPauseStart = null;
  }

  /// Build a SplitData from the current auto-split accumulators.
  SplitData _buildAutoSplitData(double distance) {
    final splitTime = _splitStartTime != null
        ? clock.now().difference(_splitStartTime!) - _splitPausedDuration
        : Duration.zero;
    return SplitData(
      intervalIndex: _state.currentSegmentIndex,
      distance: distance,
      time: splitTime,
      avgPace: _splitSampleCount > 0 ? _splitPaceSum ~/ _splitSampleCount : 0,
      avgStrokeRate:
          _splitSampleCount > 0 ? _splitSRSum ~/ _splitSampleCount : 0,
      avgWatts:
          _splitSampleCount > 0 ? _splitWattsSum ~/ _splitSampleCount : 0,
      avgHeartRate: _splitHrCount > 0 ? _splitHrSum ~/ _splitHrCount : null,
      minHeartRate: _splitMinHr,
      maxHeartRate: _splitMaxHr,
      calories:
          math.max(0, _state.latestData.calories - _splitStartCalories),
    );
  }

  /// Snapshot the current auto-split accumulators into a SplitData and reset.
  void _snapshotAutoSplit(double splitDistance) {
    _completedSplits.add(_buildAutoSplitData(splitDistance));
    _resetAutoSplitAccumulators();
  }

  void _finishCurrentSegment() {
    if (_autoSplitEnabled) {
      // Emit the final partial auto-split (distance from last threshold to end)
      final remainingDist = _state.segmentElapsedDistance - _splitStartDistance;
      if (remainingDist > 0 || _splitSampleCount > 0) {
        _completedSplits.add(
            _buildAutoSplitData(math.max(0.0, remainingDist)));
      }
      return;
    }

    // Non-auto-split: record a single split for the whole segment.
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
      minHeartRate: _segmentMinHr,
      maxHeartRate: _segmentMaxHr,
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
    _workTickTimer?.cancel();
    _workTickTimer = null;
    _workCompletionTimer?.cancel();
    _workCompletionTimer = null;
    _cancelCountdownBeeps();
    _autoPauseTimer?.cancel();
    _autoPauseTimer = null;
    _autoPauseFinishTimer?.cancel();
    _autoPauseFinishTimer = null;
  }

  /// Dispose all resources.
  void dispose() {
    _cleanup();
    _stateController.close();
    _countdownBeepController.close();
  }
}
