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
}
