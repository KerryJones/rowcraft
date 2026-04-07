import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/features/workout/workout_engine.dart';
import 'package:rowcraft/models/pm5_data.dart';
import 'package:rowcraft/models/workout.dart';
import 'package:rowcraft/models/workout_segment.dart';

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

    Workout makeWorkout(List<WorkoutSegment> segments) {
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

    test('initial state is idle', () {
      engine = WorkoutEngine(
        workout: makeWorkout([
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
        workout: makeWorkout([
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
        workout: makeWorkout([
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
        workout: makeWorkout([
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
        workout: makeWorkout([
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
        workout: makeWorkout([
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
      expect(phases, contains(WorkoutPhase.finished));
    });

    test('stop finalizes and moves to finished', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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
        workout: makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 1,
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

    test('collects split data for completed segments', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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

      // Send some data then complete
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 25,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 20),
        distance: 50,
        pace: 1150,
        strokeRate: 26,
        strokeRateUpdated: true,
        watts: 200,
        calories: 10,
        strokeCount: 40,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(engine.completedSplits.length, 1);
      final split = engine.completedSplits.first;
      expect(split.avgPace, greaterThan(0));
      expect(split.avgStrokeRate, greaterThan(0));
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

    Workout makeWorkout(List<WorkoutSegment> segments) {
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

    test('auto-pause triggers after 5s of no new strokes', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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
        workout: makeWorkout([
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
        workout: makeWorkout([
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
        workout: makeWorkout([
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
        workout: makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 30,
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
        workout: makeWorkout([
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
        workout: makeWorkout([
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

    Workout makeWorkout(List<WorkoutSegment> segments) {
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

    test('calorie segment progress advances correctly', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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
        workout: makeWorkout([
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

      expect(phases, contains(WorkoutPhase.finished));
    });

    test('per-segment calories are deltas not cumulative', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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

    test('paused time excluded from time-based segment progress', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 60,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // Row for 30s of a 60s segment
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
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.segmentProgress, closeTo(0.5, 0.01));

      // Manual pause
      engine.pause();
      expect(engine.currentState.phase, WorkoutPhase.paused);

      // Simulate 10s of pause time passing
      await Future.delayed(const Duration(seconds: 2));

      // Resume
      engine.resume();

      // Send data at 42s elapsed (30s rowing + 12s real time but only ~2s paused)
      // The paused duration should be subtracted from elapsed time for progress
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 42),
        distance: 150,
        pace: 1200,
        strokeRate: 24,
        strokeRateUpdated: true,
        watts: 180,
        calories: 10,
        strokeCount: 30,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Progress should account for paused duration being subtracted
      // Without pause subtraction it would be 42/60 = 0.7
      // With ~2s pause subtracted it should be ~(42-2)/60 = ~0.666
      final progress = engine.currentState.segmentProgress;
      expect(progress, lessThan(0.71));
      expect(progress, greaterThan(0.5));
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

    Workout makeWorkout(List<WorkoutSegment> segments) {
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

    test('manual pause does NOT auto-resume on stroke rate > 0', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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
        workout: makeWorkout([
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
        workout: makeWorkout([
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
        workout: makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 2,
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

      // Resume — should go back to resting (or advance if rest expired)
      engine.resume();
      // The rest time has elapsed, so it should advance to next work segment
      expect(
        engine.currentState.phase,
        anyOf(WorkoutPhase.resting, WorkoutPhase.rowing),
      );
    });

    test('calorie segment with non-zero start calories tracks delta', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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

      expect(engine.currentState.phase, WorkoutPhase.finished);
      expect(engine.completedSplits.last.calories, 20);
    });

    test('zero-duration rest segment advances to next work segment', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.distance,
            durationValue: 50,
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 0,
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

    Workout makeWorkout(List<WorkoutSegment> segments) {
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

    test('pace fail disabled when threshold is 0', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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
        workout: makeWorkout([
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

    Workout makeWorkout(List<WorkoutSegment> segments) {
      return Workout(
        id: 'test',
        authorId: 'user',
        title: 'Test',
        workoutType: WorkoutType.intervals,
        segments: segments,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    test('collects samples once per second during rowing', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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

    test('collects samples during rest segments', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 1, // 1 second work — completes immediately
            targetIntensity: 80,
          ),
          const WorkoutSegment(
            durationType: DurationType.time,
            durationValue: 60, // rest segment (no targetIntensity)
          ),
        ]),
        pm5Stream: pm5Controller.stream,
        paceFailThreshold: 0,
      );

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      // t=1s — work segment (completes and advances to rest)
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
      await Future.delayed(const Duration(milliseconds: 50));

      // t=2s — should be in rest segment now
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 2),
        distance: 5,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 0,
        strokeCount: 2,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Should have samples from both work and rest phases
      expect(engine.timeSamples.length, greaterThanOrEqualTo(2));
    });

    test('does not collect samples when paused', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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

    test('samples persist across segments', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
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
      await Future.delayed(const Duration(milliseconds: 50));

      // t=1s — first segment
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
      await Future.delayed(const Duration(milliseconds: 50));

      // t=2s — should be in second segment
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
      await Future.delayed(const Duration(milliseconds: 50));

      // Samples from both segments should exist
      final indices = engine.timeSamples.map((s) => s.segmentIndex).toSet();
      expect(indices.length, greaterThanOrEqualTo(2));
    });
  });
}
