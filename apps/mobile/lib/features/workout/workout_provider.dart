import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pm5_data.dart';
import '../../models/workout.dart';
import '../../models/workout_segment.dart';
import '../../models/workout_result.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import 'workout_engine.dart';

/// Combined state for the workout session UI.
class WorkoutSessionState {
  final String workoutTitle;
  final WorkoutEngineState engineState;
  final PM5Data pm5Data;
  final List<WorkoutSegment> expandedSegments;
  final bool isLoading;
  final String? error;

  const WorkoutSessionState({
    this.workoutTitle = '',
    this.engineState = const WorkoutEngineState(),
    this.pm5Data = const PM5Data.zero(),
    this.expandedSegments = const [],
    this.isLoading = false,
    this.error,
  });

  WorkoutSessionState copyWith({
    String? workoutTitle,
    WorkoutEngineState? engineState,
    PM5Data? pm5Data,
    List<WorkoutSegment>? expandedSegments,
    bool? isLoading,
    String? error,
  }) {
    return WorkoutSessionState(
      workoutTitle: workoutTitle ?? this.workoutTitle,
      engineState: engineState ?? this.engineState,
      pm5Data: pm5Data ?? this.pm5Data,
      expandedSegments: expandedSegments ?? this.expandedSegments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class WorkoutSessionNotifier extends StateNotifier<WorkoutSessionState> {
  final SupabaseService _supabaseService;
  final SyncService _syncService;

  WorkoutEngine? _engine;
  StreamSubscription<WorkoutEngineState>? _engineSub;

  /// BLE data stream controller — in production, this comes from the BLE service.
  /// For now, we expose it so the BLE layer can push data in.
  final _pm5Controller = StreamController<PM5Data>.broadcast();

  WorkoutSessionNotifier(this._supabaseService, this._syncService)
      : super(const WorkoutSessionState());

  /// Push PM5 data from BLE layer.
  void onPM5Data(PM5Data data) {
    _pm5Controller.add(data);
    state = state.copyWith(pm5Data: data);
  }

  /// Load a workout definition and prepare the engine.
  Future<void> loadWorkout(String workoutId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final workout = await _supabaseService.getWorkout(workoutId);
      _engine = WorkoutEngine(
        workout: workout,
        pm5Stream: _pm5Controller.stream,
      );

      _engineSub = _engine!.stateStream.listen((engineState) {
        state = state.copyWith(engineState: engineState);
      });

      state = state.copyWith(
        workoutTitle: workout.title,
        expandedSegments: _engine!.expandedSegments,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load workout: $e',
      );
    }
  }

  /// Start the workout.
  void start() {
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

  /// Stop the workout, save results.
  Future<void> stop() async {
    if (_engine == null) return;

    _engine!.stop();

    // Build result from engine data
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;

    final now = DateTime.now();
    final data = state.pm5Data;
    final splits = _engine!.completedSplits;

    // Compute weighted average split from completed splits (not instantaneous)
    int avgSplit = data.pace; // fallback to instantaneous
    int avgSR = data.strokeRate;
    int avgW = data.watts;
    if (splits.isNotEmpty) {
      int paceSum = 0, srSum = 0, wattsSum = 0;
      for (final s in splits) {
        paceSum += s.avgPace;
        srSum += s.avgStrokeRate;
        wattsSum += s.avgWatts;
      }
      avgSplit = paceSum ~/ splits.length;
      avgSR = srSum ~/ splits.length;
      avgW = wattsSum ~/ splits.length;
    }

    final result = WorkoutResult(
      id: '', // Let Supabase generate
      userId: userId,
      workoutId: _engine!.workout.id,
      startedAt: now.subtract(data.elapsedTime),
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

    // Queue for sync (offline-first)
    await _syncService.queueResult(result);
  }

  @override
  void dispose() {
    _engineSub?.cancel();
    _engine?.dispose();
    _pm5Controller.close();
    super.dispose();
  }
}

final workoutSessionProvider =
    StateNotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>((ref) {
  return WorkoutSessionNotifier(
    ref.watch(supabaseServiceProvider),
    ref.watch(syncServiceProvider),
  );
});
