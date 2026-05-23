import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/features/workout/workout_engine.dart';
import 'package:rowcraft/models/pm5_data.dart';
import 'package:rowcraft/models/workout.dart';
import 'package:rowcraft/models/workout_segment.dart';

Workout _makeWorkout(List<WorkoutSegment> segments) {
  return Workout(
    id: 'test-workout',
    authorId: 'test-user',
    title: 'Test Workout',
    workoutType: WorkoutType.intervals,
    segments: segments,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('WorkoutEngine', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });

    test('initial state is idle', () {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 500,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      expect(engine.currentState.phase, WorkoutPhase.idle);
    });

    test('start immediately begins rowing', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 500,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final states = <WorkoutPhase>[];
      engine.stateStream.listen((s) => states.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(states.first, WorkoutPhase.rowing);
    });

    test('ready phase transitions to rowing on first stroke', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 500,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.ready();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.ready);

      // Simulate first stroke
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 1),
        distance: 2,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 0,
        strokeCount: 1,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(phases, contains(WorkoutPhase.rowing));
    });

    test('ready phase updates latestData while waiting', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 500,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.ready();
      await Future.delayed(const Duration(milliseconds: 50));

      // Send data with zero stroke rate (not rowing yet)
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 1),
        distance: 0,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 0,
        strokeCount: 0,
        intervalCount: 0,
        heartRate: 72,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Should still be in ready phase but have updated data
      expect(engine.currentState.phase, WorkoutPhase.ready);
      expect(engine.currentState.latestData.heartRate, 72);
    });

    test('handles multiple individual segments', () {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 500,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 500,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 500,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      expect(engine.expandedSegments.length, 3);
    });

    test('completes segment when distance reached', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulate PM5 data showing 100m completed
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 30),
        distance: 100,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 10,
        strokeCount: 60,
        intervalCount: 1,
      ));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(phases, contains(WorkoutPhase.structuredComplete));
    });

    test('stop finalizes and moves to finished', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      engine.stop();
      expect(engine.currentState.phase, WorkoutPhase.finished);
    });

    test('transitions between work and rest segments', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 1,
            isRest: true,
          ),
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete first work segment
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 30,
        intervalCount: 1,
      ));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(phases, contains(WorkoutPhase.resting));

      // Wait for rest to finish (1 second)
      await Future.delayed(const Duration(seconds: 2));
      expect(phases, contains(WorkoutPhase.rowing));
    });

    test('rest countdown advances via wall-clock without PM5 frames', () async {
      // Bug fix: rest progress must tick even when PM5 stops sending data
      // (rower stops → PM5 auto-pauses its internal clock).
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 5,
            isRest: true,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Trigger end of work segment — no further PM5 frames after this
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(engine.currentState.phase, WorkoutPhase.resting);

      // Wait 2 seconds with no PM5 data — tick timer should advance progress
      await Future.delayed(const Duration(seconds: 2));

      // Progress should be ~40% (2/5s), definitely > 0
      expect(engine.currentState.segmentProgress, greaterThan(0.1));
      expect(engine.currentState.phase, WorkoutPhase.resting);

      // Pause — progress should stop advancing
      engine.pause();
      final progressAtPause = engine.currentState.segmentProgress;
      await Future.delayed(const Duration(seconds: 1));
      expect(engine.currentState.segmentProgress, closeTo(progressAtPause, 0.05));

      // Resume — progress should continue
      engine.resume();
      await Future.delayed(const Duration(seconds: 1));
      expect(
        engine.currentState.segmentProgress,
        greaterThan(progressAtPause + 0.05),
      );
    });

    test('PM5 frames during timed rest do not overwrite wall-clock segmentProgress', () async {
      // Regression: _onPM5Data previously competed with _tickRest to set
      // segmentProgress during rest, causing flickering when flywheel spin-down
      // data arrived between tick intervals.
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 10,
            isRest: true,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete the work segment to enter rest
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(engine.currentState.phase, WorkoutPhase.resting);

      // Let the wall-clock tick advance progress by ~3 seconds
      await Future.delayed(const Duration(seconds: 3));
      final progressAfterTick = engine.currentState.segmentProgress;
      expect(progressAfterTick, greaterThan(0.1));

      // Send a PM5 frame with stale elapsed time (flywheel spin-down scenario).
      // PM5 elapsed hasn't advanced much — without the fix, this would reset
      // segmentProgress to near 0, causing the countdown to jump backwards.
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 11), // only 1s past segment start
        distance: 51,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Progress must not have regressed — PM5 frame must not have overwritten it
      expect(
        engine.currentState.segmentProgress,
        greaterThanOrEqualTo(progressAfterTick - 0.05),
      );
    });

    test('collects split data for completed segments', () async {
      // Single 50m distance segment auto-splits into 5x10m sub-splits
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Send data at 10m intervals to match auto-split thresholds
      for (var dist = 10.0; dist <= 50; dist += 10) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: (dist * 0.4).round()),
          distance: dist,
          pace: 1200,
          strokeRate: 24,
          strokeRateUpdated: true,
          watts: 180,
          calories: (dist / 5).round(),
          strokeCount: (dist * 0.4).round(),
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(milliseconds: 20));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // 50m / 5 = 10m auto-splits → 5 splits
      expect(engine.completedSplits.length, 5);
      for (final split in engine.completedSplits) {
        expect(split.avgPace, greaterThan(0));
        expect(split.avgStrokeRate, greaterThan(0));
      }
    });
  });

  group('Auto-pause', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });


    test('auto-pause triggers after 5s of no new strokes', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final states = <WorkoutEngineState>[];
      engine.stateStream.listen((s) => states.add(s));

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Send normal rowing data first
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.rowing);

      // Send zero stroke rate (strokeCount unchanged) — should not immediately pause
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 11),
        distance: 50,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.rowing);

      // Wait 6+ seconds — the periodic timer (1s interval) checks
      // if _lastActivityAt is >= 5s ago, needs ~6s for timer
      // alignment and inSeconds truncation.
      await Future.delayed(const Duration(seconds: 6));

      expect(engine.currentState.phase, WorkoutPhase.paused);
      expect(engine.currentState.isAutoPaused, true);
    });

    test('auto-pause triggers during spin-down (SR > 0 but no new strokes)', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Normal rowing
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulate flywheel spin-down: SR still > 0 but strokeCount unchanged.
      // Send multiple spin-down packets to verify they don't reset the timer.
      for (var i = 0; i < 3; i++) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: 12 + i),
          distance: 52.0 + i * 0.5,
          pace: 1500 + i * 100,
          strokeRate: 10 - i * 3,
          strokeRateUpdated: true,
          watts: 50 - i * 15,
          calories: 5,
          strokeCount: 20,
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(seconds: 1));
      }

      expect(engine.currentState.phase, WorkoutPhase.rowing);

      // Wait for auto-pause (5s from last strokeCount change + timer alignment)
      await Future.delayed(const Duration(seconds: 4));

      expect(engine.currentState.phase, WorkoutPhase.paused);
      expect(engine.currentState.isAutoPaused, true);
    });

    test('auto-resume when stroke rate returns > 0', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Normal rowing
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // No new strokes to trigger auto-pause
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 11),
        distance: 50,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(seconds: 6));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 18),
        distance: 50,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.paused);
      expect(engine.currentState.isAutoPaused, true);

      // Resume rowing — new stroke (strokeCount changes)
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 20),
        distance: 55,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 6,
        strokeCount: 22,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.rowing);
      expect(engine.currentState.isAutoPaused, false);
    });

    test('no auto-resume on flywheel spin-down (SR > 0 but no new strokes)',
        () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Normal rowing
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Stop rowing — wait for auto-pause
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 11),
        distance: 50,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(seconds: 6));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 18),
        distance: 50,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.paused);
      expect(engine.currentState.isAutoPaused, true);

      // Flywheel spin-down: SR > 0 but strokeCount unchanged
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 19),
        distance: 50,
        pace: 1400,
        strokeRate: 18,
        strokeRateUpdated: true,
        watts: 100,
        calories: 5,
        strokeCount: 20, // Same — no new strokes
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Should still be paused
      expect(engine.currentState.phase, WorkoutPhase.paused);
      expect(engine.currentState.isAutoPaused, true);

      // Now an actual new stroke resumes
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 21),
        distance: 55,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 6,
        strokeCount: 21, // New stroke
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.rowing);
      expect(engine.currentState.isAutoPaused, false);
    });

    test('no auto-pause during rest segments', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 30,
            isRest: true,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete work segment to enter rest
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(engine.currentState.phase, WorkoutPhase.resting);

      // Send zero SR during rest — should NOT auto-pause
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 16),
        distance: 50,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 5,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(seconds: 6));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 22),
        distance: 50,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 5,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Should still be resting, not paused
      expect(engine.currentState.phase, WorkoutPhase.resting);
    });

    test('manual pause/resume sets correct phase and isAutoPaused flag',
        () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Send some data to be in rowing state
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.rowing);

      // Manual pause
      engine.pause();
      expect(engine.currentState.phase, WorkoutPhase.paused);
      expect(engine.currentState.isAutoPaused, false);

      // Manual resume
      engine.resume();
      expect(engine.currentState.phase, WorkoutPhase.rowing);
      expect(engine.currentState.isAutoPaused, false);
    });

    test('zero-SR samples excluded from averages', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Send normal rowing data
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Send zero SR data (should NOT be accumulated)
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 11),
        distance: 50,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Send more normal data
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 12),
        distance: 100,
        pace: 1100,
        strokeRate: 26,
        strokeRateUpdated: true,
        watts: 200,
        calories: 10,
        strokeCount: 25,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Stop and check averages — should only have 2 samples (not 3)
      engine.stop();

      expect(engine.completedSplits.length, 1);
      final split = engine.completedSplits.first;
      // Average of 1200 and 1100 = 1150, not (1200+0+1100)/3 = 766
      expect(split.avgPace, 1150);
      // Average of 24 and 26 = 25, not (24+0+26)/3 = 16
      expect(split.avgStrokeRate, 25);
      // Average of 180 and 200 = 190, not (180+0+200)/3 = 126
      expect(split.avgWatts, 190);
    });
  });

  group('Calorie tracking', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });


    test('calorie segment progress advances correctly', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.calories,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // 50 of 100 calories
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 60),
        distance: 250,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 50,
        strokeCount: 60,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.segmentProgress, closeTo(0.5, 0.01));
      expect(engine.currentState.segmentElapsedCalories, 50);
    });

    test('calorie segment auto-completes at target', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.calories,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Hit 100 calories target
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 120),
        distance: 500,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 100,
        strokeCount: 120,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(phases, contains(WorkoutPhase.structuredComplete));
    });

    test('per-segment calories are deltas not cumulative', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete first segment with 10 cumulative calories
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 10,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      // Complete second segment with 25 cumulative calories
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 30),
        distance: 100,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 25,
        strokeCount: 60,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(engine.completedSplits.length, 2);
      // First segment: 10 - 0 = 10 calories
      expect(engine.completedSplits[0].calories, 10);
      // Second segment: 25 - 10 = 15 calories (delta, not cumulative)
      expect(engine.completedSplits[1].calories, 15);
    });

    test('paused time excluded from time-based segment progress', () {
      fakeAsync((async) {
        engine = WorkoutEngine(
          workout: _makeWorkout([
            const WorkoutSegment(
              durationType: DurationType.time,
              durationValue: 60,
            ),
          ]),
          pm5Stream: pm5Controller.stream,
        );

        engine.start();
        // Advance 30s so wall-clock progress reaches 0.5
        async.elapse(const Duration(seconds: 30));

        pm5Controller.add(const PM5Data(
          elapsedTime: Duration(seconds: 30),
          distance: 150,
          pace: 1200,
          strokeRate: 24,
          strokeRateUpdated: true,
          watts: 180,
          calories: 10,
          strokeCount: 30,
          intervalCount: 1,
        ));
        async.flushMicrotasks();

        expect(engine.currentState.segmentProgress, closeTo(0.5, 0.02));

        // Manual pause
        engine.pause();
        expect(engine.currentState.phase, WorkoutPhase.paused);

        // Simulate 10s of pause time passing
        async.elapse(const Duration(seconds: 10));

        // Resume — paused duration should be 10s
        engine.resume();

        // Advance 2 more seconds of rowing (total rowing = 32s)
        async.elapse(const Duration(seconds: 2));

        // Progress should be ~32/60 ≈ 0.533, NOT (30+10+2)/60 = 0.7
        final progress = engine.currentState.segmentProgress;
        expect(progress, closeTo(32 / 60, 0.02));
      });
    });
  });

  group('Pause edge cases', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });


    test('manual pause does NOT auto-resume on stroke rate > 0', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Row normally
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Manual pause
      engine.pause();
      expect(engine.currentState.phase, WorkoutPhase.paused);
      expect(engine.currentState.isAutoPaused, false);

      // Send data with SR > 0 — should NOT auto-resume
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 12),
        distance: 55,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 6,
        strokeCount: 22,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Should still be paused
      expect(engine.currentState.phase, WorkoutPhase.paused);
      expect(engine.currentState.isAutoPaused, false);
    });

    test('double pause does not corrupt prePausePhase', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Pause once
      engine.pause();
      expect(engine.currentState.phase, WorkoutPhase.paused);

      // Pause again — should be no-op
      engine.pause();
      expect(engine.currentState.phase, WorkoutPhase.paused);

      // Resume should restore to rowing (not paused)
      engine.resume();
      expect(engine.currentState.phase, WorkoutPhase.rowing);
    });

    test('stop while paused produces finished state', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      engine.pause();
      expect(engine.currentState.phase, WorkoutPhase.paused);

      // Wait a measurable amount so pause duration is non-zero
      await Future.delayed(const Duration(seconds: 1));

      engine.stop();
      expect(engine.currentState.phase, WorkoutPhase.finished);
      expect(engine.currentState.finishReason, FinishReason.userStopped);
      expect(engine.completedSplits.length, 1);
      // Verify pause duration was accumulated before finalization
      expect(engine.currentState.pausedDuration, greaterThan(Duration.zero));
    });

    test('pause during rest, rest timer does not fire', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 2,
            isRest: true,
          ),
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete work to enter rest
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(engine.currentState.phase, WorkoutPhase.resting);

      // Pause during rest
      engine.pause();
      expect(engine.currentState.phase, WorkoutPhase.paused);

      // Wait longer than the 2s rest timer
      await Future.delayed(const Duration(seconds: 3));

      // Should still be paused — rest timer should NOT have fired
      expect(engine.currentState.phase, WorkoutPhase.paused);

      // Resume — paused duration ≈ 3s but wall-clock elapsed ~0.1s before pause,
      // so remaining rest ≈ (2 - (3.1 - 3.0)) ≈ 1.9s. Engine re-enters resting.
      engine.resume();
      expect(
        engine.currentState.phase,
        anyOf(WorkoutPhase.resting, WorkoutPhase.rowing),
      );
    });

    test('calorie segment with non-zero start calories tracks delta', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.calories,
            durationValue: 20,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete first segment with 30 cumulative calories
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 30,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      // Now in calorie segment, start calories = 30
      expect(engine.currentState.phase, WorkoutPhase.rowing);

      // Send data: 40 cumulative = 10 delta of 20 target = 50% progress
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 25),
        distance: 100,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 40,
        strokeCount: 50,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.segmentProgress, closeTo(0.5, 0.01));
      expect(engine.currentState.segmentElapsedCalories, 10);

      // Complete: 50 cumulative = 20 delta = 100%
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 35),
        distance: 150,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 50,
        strokeCount: 70,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(engine.currentState.phase, WorkoutPhase.structuredComplete);
      expect(engine.completedSplits.last.calories, 20);
    });

    test('zero-duration rest segment advances to next work segment', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 0,
            isRest: true,
          ),
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete first work segment
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 30,
        intervalCount: 1,
      ));
      // Let the zero-duration timer fire
      await Future.delayed(const Duration(milliseconds: 200));

      // Should have passed through resting and into rowing for segment 2
      expect(engine.currentState.phase, WorkoutPhase.rowing);
      expect(engine.currentState.currentSegmentIndex, 2);
    });
  });

  group('Pace fail threshold', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });


    test('pace fail disabled when threshold is 0', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Send pace well above max (too slow) for 16+ seconds.
      // Send every 2s with incrementing strokeCount to stay within the 5s auto-pause window.
      for (var i = 0; i < 8; i++) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: 10 + i * 2),
          distance: 50.0 + i * 10,
          pace: 1500, // Way above max of 1200
          strokeRate: 20,
          strokeRateUpdated: true,
          watts: 100,
          calories: 5 + i,
          strokeCount: 20 + i * 2,
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(seconds: 2));
      }

      // Should still be rowing (not finished due to pace fail)
      expect(engine.currentState.phase, WorkoutPhase.rowing);
      expect(engine.currentState.secondsOutOfRange, 0);
    });

    test('pace fail triggers when threshold > 0 and pace exceeds max', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
            targetIntensity: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 5,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Send pace above max for 6+ seconds.
      // Send every 2s with incrementing strokeCount to stay within the 5s auto-pause window.
      for (var i = 0; i < 4; i++) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: 10 + i * 2),
          distance: 50.0 + i * 10,
          pace: 1500,
          strokeRate: 20,
          strokeRateUpdated: true,
          watts: 100,
          calories: 5 + i,
          strokeCount: 20 + i * 2,
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(seconds: 2));
      }

      expect(engine.currentState.phase, WorkoutPhase.finished);
      expect(engine.currentState.finishReason, FinishReason.paceFailed);
    });
  });

  group('structuredComplete flow', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });


    test('finishFromStructuredComplete transitions to finished', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete the segment
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 30),
        distance: 100,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 10,
        strokeCount: 60,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(engine.currentState.phase, WorkoutPhase.structuredComplete);

      engine.finishFromStructuredComplete();
      expect(engine.currentState.phase, WorkoutPhase.finished);
    });

    test('continueWithFreeRow appends free segment and re-enters rowing', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete the segment
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 30),
        distance: 100,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 10,
        strokeCount: 60,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));
      expect(engine.currentState.phase, WorkoutPhase.structuredComplete);

      engine.continueWithFreeRow();
      expect(engine.currentState.phase, WorkoutPhase.rowing);
      // Verify a new free segment was added
      expect(engine.expandedSegments.last.isRest, false);
      expect(engine.expandedSegments.last.targetIntensity, isNull);
    });

    test('continueWithFreeRow is a no-op outside structuredComplete', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(engine.currentState.phase, WorkoutPhase.rowing);

      engine.continueWithFreeRow(); // no-op
      expect(engine.currentState.phase, WorkoutPhase.rowing);
    });

    test('finishFromStructuredComplete is a no-op outside structuredComplete', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(engine.currentState.phase, WorkoutPhase.rowing);

      engine.finishFromStructuredComplete(); // no-op
      expect(engine.currentState.phase, WorkoutPhase.rowing);
    });
  });

  group('Time-series sampling', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });


    test('collects samples once per second during rowing', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 5000,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Send data at t=1s, t=1.5s, t=2s, t=3s
      for (final sec in [1.0, 1.5, 2.0, 3.0]) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(milliseconds: (sec * 1000).toInt()),
          distance: sec * 5,
          pace: 1200,
          strokeRate: 24,
          strokeRateUpdated: true,
          watts: 180,
          calories: 0,
          strokeCount: (sec * 2).toInt(),
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Should have 3 samples (t=1, t=2, t=3) — t=1.5 skipped (< 1s since t=1)
      expect(engine.timeSamples.length, 3);
      expect(engine.timeSamples[0].pace, 1200);
      expect(engine.timeSamples[0].strokeRate, 24);
      expect(engine.timeSamples[0].segmentIndex, 0);
    });

    test('collects samples during rest segments', () {
      fakeAsync((async) {
        engine = WorkoutEngine(
          workout: _makeWorkout([
            const WorkoutSegment(
              durationType: DurationType.time,
              durationValue: 1, // 1 second work — completes via wall-clock
              targetIntensity: 80,
            ),
            const WorkoutSegment(
              durationType: DurationType.time,
              durationValue: 60, // rest segment
              isRest: true,
            ),
          ]),
          pm5Stream: pm5Controller.stream,
          paceFailThreshold: 0,
        );

        engine.start();
        async.flushMicrotasks();

        // Send PM5 data during work segment (before wall-clock completes it)
        pm5Controller.add(const PM5Data(
          elapsedTime: Duration(milliseconds: 500),
          distance: 2,
          pace: 1200,
          strokeRate: 24,
          strokeRateUpdated: true,
          watts: 180,
          calories: 0,
          strokeCount: 1,
          intervalCount: 1,
        ));
        async.flushMicrotasks();

        // Advance past 1s work segment — wall-clock timer fires, advances to rest
        async.elapse(const Duration(seconds: 1));

        // Now in rest — send PM5 data
        pm5Controller.add(const PM5Data(
          elapsedTime: Duration(seconds: 2),
          distance: 5,
          pace: 0,
          strokeRate: 0,
          watts: 0,
          calories: 0,
          strokeCount: 1,
          intervalCount: 1,
        ));
        async.flushMicrotasks();

        // Should have samples from both work and rest phases
        expect(engine.timeSamples.length, greaterThanOrEqualTo(2));
      });
    });

    test('does not collect samples when paused', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 5000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // t=1s — rowing
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 1),
        distance: 5,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 0,
        strokeCount: 2,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 10));

      final countBeforePause = engine.timeSamples.length;

      // Pause
      engine.pause();
      await Future.delayed(const Duration(milliseconds: 10));

      // t=2s — paused, should not collect
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 2),
        distance: 5,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 0,
        strokeCount: 2,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(engine.timeSamples.length, countBeforePause);
    });

    test('samples persist across segments', () {
      fakeAsync((async) {
        engine = WorkoutEngine(
          workout: _makeWorkout([
            const WorkoutSegment(
              durationType: DurationType.time,
              durationValue: 1,
            ),
            const WorkoutSegment(
              durationType: DurationType.time,
              durationValue: 60,
            ),
          ]),
          pm5Stream: pm5Controller.stream,
          paceFailThreshold: 0,
        );

        engine.start();
        async.flushMicrotasks();

        // Send PM5 data during first segment (before wall-clock completes it)
        pm5Controller.add(const PM5Data(
          elapsedTime: Duration(milliseconds: 500),
          distance: 2,
          pace: 1200,
          strokeRate: 24,
          strokeRateUpdated: true,
          watts: 180,
          calories: 0,
          strokeCount: 1,
          intervalCount: 1,
        ));
        async.flushMicrotasks();

        // Advance past 1s — wall-clock timer fires, advances to second segment
        async.elapse(const Duration(seconds: 1));

        // Send PM5 data during second segment
        pm5Controller.add(const PM5Data(
          elapsedTime: Duration(seconds: 2),
          distance: 10,
          pace: 1200,
          strokeRate: 24,
          strokeRateUpdated: true,
          watts: 180,
          calories: 0,
          strokeCount: 4,
          intervalCount: 1,
        ));
        async.flushMicrotasks();

        // Samples from both segments should exist
        final indices = engine.timeSamples.map((s) => s.segmentIndex).toSet();
        expect(indices.length, greaterThanOrEqualTo(2));
      });
    });
  });

  group('Countdown beep stream', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });


    test('emits 3,2,1,0 for time-based work segment', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 5, // 5 seconds
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      final beeps = <int>[];
      engine.countdownBeepStream.listen(beeps.add);

      engine.start();
      // Wait for the full segment + buffer
      await Future.delayed(const Duration(seconds: 6));

      expect(beeps, [3, 2, 1, 0]);
    });

    test('emits 3,2,1,0 for time-based rest segment', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 5,
            isRest: true,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      final beeps = <int>[];
      engine.countdownBeepStream.listen(beeps.add);

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete work segment to enter rest
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 30,
        intervalCount: 1,
      ));

      // Wait for rest countdown (5s segment, beep at T-3)
      await Future.delayed(const Duration(seconds: 6));

      expect(beeps, [3, 2, 1, 0]);
    });

    test('does not emit for distance-based segments', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 100,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      final beeps = <int>[];
      engine.countdownBeepStream.listen(beeps.add);

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete it
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 30),
        distance: 100,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 10,
        strokeCount: 60,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(beeps, isEmpty);
    });

    test('does not emit for calorie-based segments', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.calories,
            durationValue: 10,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      final beeps = <int>[];
      engine.countdownBeepStream.listen(beeps.add);

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 30),
        distance: 200,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 10,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(beeps, isEmpty);
    });

    test('does not emit for segments shorter than 4 seconds', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 3,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      final beeps = <int>[];
      engine.countdownBeepStream.listen(beeps.add);

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      expect(beeps, isEmpty);
    });

    test('pause during countdown resumes remaining beeps', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 6,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      final beeps = <int>[];
      engine.countdownBeepStream.listen(beeps.add);

      engine.start();
      // Wait until first beep fires (T-3, at 3s into 6s segment)
      await Future.delayed(const Duration(milliseconds: 3500));
      expect(beeps, contains(3));

      // Pause mid-countdown
      engine.pause();
      final beepsAtPause = List<int>.from(beeps);
      await Future.delayed(const Duration(seconds: 2));
      // No new beeps during pause
      expect(beeps, beepsAtPause);

      // Resume — remaining beeps should fire
      engine.resume();
      await Future.delayed(const Duration(seconds: 4));

      // Should have all 4 beeps (3, 2, 1, 0)
      expect(beeps, containsAllInOrder([3, 2, 1, 0]));
    });
  });

  group('autoSplitDistance()', () {
    test('2000m returns 500m (C2 exception)', () {
      expect(autoSplitDistance(2000), 500);
    });

    test('42195m (marathon) returns 2000m (C2 exception)', () {
      expect(autoSplitDistance(42195), 2000);
    });

    test('500m returns 100m (fifths)', () {
      expect(autoSplitDistance(500), 100);
    });

    test('1000m returns 200m (fifths)', () {
      expect(autoSplitDistance(1000), 200);
    });

    test('5000m returns 1000m (fifths)', () {
      expect(autoSplitDistance(5000), 1000);
    });

    test('10000m returns 2000m (fifths)', () {
      expect(autoSplitDistance(10000), 2000);
    });

    test('6000m returns 1200m (fifths, non-round)', () {
      expect(autoSplitDistance(6000), 1200);
    });

    test('0 returns 0', () {
      expect(autoSplitDistance(0), 0);
    });

    test('negative returns 0', () {
      expect(autoSplitDistance(-100), 0);
    });
  });

  group('Auto-split engine behavior', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });

    test('2000m single-distance produces 4x500m auto-splits', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulate rowing at ~2:00/500m pace, sending data at each 500m boundary
      for (var dist = 100.0; dist <= 2000; dist += 100) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: (dist / 2.5).round()),
          distance: dist,
          pace: 1200,
          strokeRate: 28,
          strokeRateUpdated: true,
          watts: 210,
          calories: (dist / 20).round(),
          strokeCount: (dist / 2.5).round(),
          intervalCount: 1,
          heartRate: 155,
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Should have 4 splits (4x500m)
      expect(engine.completedSplits.length, 4);

      // Each split should have ~500m distance
      for (final split in engine.completedSplits) {
        expect(split.distance, closeTo(500, 50));
        expect(split.avgPace, 1200);
        expect(split.avgStrokeRate, 28);
        expect(split.avgHeartRate, 155);
      }
    });

    test('10000m single-distance produces 5x2000m auto-splits', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 10000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Send data at every 1000m (two points per split)
      for (var dist = 1000.0; dist <= 10000; dist += 1000) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: (dist / 2.5).round()),
          distance: dist,
          pace: 1200,
          strokeRate: 26,
          strokeRateUpdated: true,
          watts: 200,
          calories: (dist / 10).round(),
          strokeCount: (dist / 2.5).round(),
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Should have 5 splits (5x2000m)
      expect(engine.completedSplits.length, 5);
    });

    test('multi-segment workout does NOT auto-split', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 500,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 60,
            isRest: true,
          ),
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 500,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Complete first segment
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 120),
        distance: 500,
        pace: 1200,
        strokeRate: 28,
        strokeRateUpdated: true,
        watts: 210,
        calories: 25,
        strokeCount: 100,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      // First segment should produce 1 split (not auto-split into 5x100m)
      expect(engine.completedSplits.length, 1);
      expect(engine.completedSplits.first.distance, closeTo(500, 5));
    });

    test('auto-split accumulators track per-split averages correctly', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // First 500m at pace 1200
      for (var dist = 100.0; dist <= 500; dist += 100) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: (dist / 2.5).round()),
          distance: dist,
          pace: 1200,
          strokeRate: 28,
          strokeRateUpdated: true,
          watts: 210,
          calories: (dist / 20).round(),
          strokeCount: (dist / 2.5).round(),
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Second 500m at pace 1100 (faster)
      for (var dist = 600.0; dist <= 1000; dist += 100) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: (dist / 2.5).round()),
          distance: dist,
          pace: 1100,
          strokeRate: 30,
          strokeRateUpdated: true,
          watts: 240,
          calories: (dist / 20).round(),
          strokeCount: (dist / 2.5).round(),
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Stop here to check the first two completed splits
      expect(engine.completedSplits.length, 2);
      expect(engine.completedSplits[0].avgPace, 1200);
      expect(engine.completedSplits[0].avgStrokeRate, 28);
      expect(engine.completedSplits[1].avgPace, 1100);
      expect(engine.completedSplits[1].avgStrokeRate, 30);
    });

    test('stop mid-workout emits final partial auto-split', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Row 700m (past first 500m split, 200m into second)
      for (var dist = 100.0; dist <= 700; dist += 100) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: (dist / 2.5).round()),
          distance: dist,
          pace: 1200,
          strokeRate: 28,
          strokeRateUpdated: true,
          watts: 210,
          calories: (dist / 20).round(),
          strokeCount: (dist / 2.5).round(),
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      engine.stop();

      // Should have 2 splits: 500m complete + ~200m partial
      expect(engine.completedSplits.length, 2);
      expect(engine.completedSplits[0].distance, closeTo(500, 50));
      expect(engine.completedSplits[1].distance, closeTo(200, 50));
    });

    test('timed single-segment does NOT auto-split', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 1200,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 28,
        strokeRateUpdated: true,
        watts: 210,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      engine.stop();

      // Should have exactly 1 split (no auto-splitting for time-based)
      expect(engine.completedSplits.length, 1);
    });
  });

  group('structuredComplete does not accumulate extra splits', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });


    test('PM5 data after calorie segment completion does not create extra splits', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.calories,
            durationValue: 5,
            targetIntensity: 70,
            targetHrZone: 2,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulate rowing: first stroke starts the workout
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 1),
        distance: 5,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 0,
        strokeCount: 1,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Row until 5 calories — segment should complete
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 30),
        distance: 200,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.structuredComplete);
      final splitsAtComplete = engine.completedSplits.length;
      expect(splitsAtComplete, 1);

      // More PM5 data arrives after completion — should NOT create new splits
      for (var i = 0; i < 10; i++) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: 31 + i),
          distance: 210.0 + i * 5,
          pace: 1200,
          strokeRate: 24,
          strokeRateUpdated: true,
          watts: 180,
          calories: 6 + i,
          strokeCount: 31 + i,
          intervalCount: 1,
        ));
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Splits count should NOT have increased
      expect(engine.completedSplits.length, splitsAtComplete);
    });
  });

  group('Per-segment ending heart rate', () {
    late StreamController<PM5Data> pm5Controller;
    late WorkoutEngine engine;

    setUp(() {
      pm5Controller = StreamController<PM5Data>.broadcast();
    });

    tearDown(() {
      engine.dispose();
      pm5Controller.close();
    });

    test('captures last HR sample of each segment into SplitData', () async {
      engine = WorkoutEngine(
        workout: _makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 100,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 100,
            targetIntensity: 80,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Segment 1: HR ramps 140 -> 150 -> 160, then segment completes at 100m.
      final hrs1 = [140, 150, 160];
      for (var i = 0; i < hrs1.length; i++) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: 10 + i * 5),
          distance: 30.0 + i * 35,
          pace: 1200,
          strokeRate: 28,
          strokeRateUpdated: true,
          watts: 210,
          calories: 5 + i,
          strokeCount: 10 + i * 5,
          intervalCount: 1,
          heartRate: hrs1[i],
        ));
        await Future.delayed(const Duration(milliseconds: 20));
      }

      // Segment 2: HR ramps 145 -> 158 -> 170 (final value should land as ending).
      final hrs2 = [145, 158, 170];
      for (var i = 0; i < hrs2.length; i++) {
        pm5Controller.add(PM5Data(
          elapsedTime: Duration(seconds: 30 + i * 5),
          distance: 130.0 + i * 35,
          pace: 1200,
          strokeRate: 28,
          strokeRateUpdated: true,
          watts: 210,
          calories: 8 + i,
          strokeCount: 25 + i * 5,
          intervalCount: 2,
          heartRate: hrs2[i],
        ));
        await Future.delayed(const Duration(milliseconds: 20));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(engine.completedSplits.length, 2);
      expect(engine.completedSplits[0].endingHeartRate, 160);
      expect(engine.completedSplits[1].endingHeartRate, 170);
    });
  });
}
