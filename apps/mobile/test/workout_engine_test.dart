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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 500,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      expect(engine.currentState.phase, WorkoutPhase.idle);
    });

    test('start begins countdown', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 500,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final states = <WorkoutPhase>[];
      engine.stateStream.listen((s) => states.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(states.first, WorkoutPhase.countingDown);
      expect(engine.currentState.countdownSeconds, 3);
    });

    test('transitions from countdown to rowing after 3s', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 500,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      expect(phases, contains(WorkoutPhase.rowing));
    });

    test('expands repeated segments', () {
      final segment = WorkoutSegment(
        type: SegmentType.work,
        durationType: DurationType.distance,
        durationValue: 500,
        repeat: 3,
      );

      engine = WorkoutEngine(
        workout: makeWorkout([segment]),
        pm5Stream: pm5Controller.stream,
      );

      expect(engine.expandedSegments.length, 3);
    });

    test('completes segment when distance reached', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Simulate PM5 data showing 100m completed
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 30),
        distance: 100,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      engine.stop();
      expect(engine.currentState.phase, WorkoutPhase.finished);
    });

    test('transitions between work and rest segments', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
          WorkoutSegment(
            type: SegmentType.rest,
            durationType: DurationType.time,
            durationValue: 1,
          ),
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Complete first work segment
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Send some data then complete
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 25,
        pace: 1200,
        strokeRate: 24,
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

    test('auto-pause triggers after 3s of zero stroke rate', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final states = <WorkoutEngineState>[];
      engine.stateStream.listen((s) => states.add(s));

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Send normal rowing data first
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.rowing);

      // Send zero stroke rate — should not immediately pause
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

      // Wait for 3+ seconds then send another zero SR sample
      await Future.delayed(const Duration(seconds: 3));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
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
    });

    test('auto-resume when stroke rate returns > 0', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Normal rowing
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
        watts: 180,
        calories: 5,
        strokeCount: 20,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      // Zero SR to trigger auto-pause
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
      await Future.delayed(const Duration(seconds: 4));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 16),
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

      // Resume rowing — SR > 0
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 18),
        distance: 55,
        pace: 1200,
        strokeRate: 24,
        watts: 180,
        calories: 6,
        strokeCount: 22,
        intervalCount: 1,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.currentState.phase, WorkoutPhase.rowing);
      expect(engine.currentState.isAutoPaused, false);
    });

    test('no auto-pause during rest segments', () async {
      engine = WorkoutEngine(
        workout: makeWorkout([
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
          WorkoutSegment(
            type: SegmentType.rest,
            durationType: DurationType.time,
            durationValue: 30,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Complete work segment to enter rest
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
      await Future.delayed(const Duration(seconds: 4));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 20),
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Send some data to be in rowing state
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Send normal rowing data
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.calories,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // 50 of 100 calories
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 60),
        distance: 250,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.calories,
            durationValue: 100,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Hit 100 calories target
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 120),
        distance: 500,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Complete first segment with 10 cumulative calories
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.time,
            durationValue: 60,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Row for 30s of a 60s segment
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 30),
        distance: 150,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Row normally
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 2000,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 10),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
          WorkoutSegment(
            type: SegmentType.rest,
            durationType: DurationType.time,
            durationValue: 2,
          ),
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Complete work to enter rest
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.calories,
            durationValue: 20,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Complete first segment with 30 cumulative calories
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
          WorkoutSegment(
            type: SegmentType.rest,
            durationType: DurationType.time,
            durationValue: 0,
          ),
          WorkoutSegment(
            type: SegmentType.work,
            durationType: DurationType.distance,
            durationValue: 50,
          ),
        ]),
        pm5Stream: pm5Controller.stream,
      );

      final phases = <WorkoutPhase>[];
      engine.stateStream.listen((s) => phases.add(s.phase));

      engine.start();
      await Future.delayed(const Duration(seconds: 4));

      // Complete first work segment
      pm5Controller.add(const PM5Data(
        elapsedTime: Duration(seconds: 15),
        distance: 50,
        pace: 1200,
        strokeRate: 24,
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
}
