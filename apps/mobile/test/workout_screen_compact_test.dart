// Widget tests for the compact workout layout:
// - renders 6 stat tiles with expected values
// - tap on SEGMENT tile flips label between countdown and count-up
// - effectiveDisplayMode picks compact for phones, classic for tablets

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rowcraft/features/ble/ble_provider.dart';
import 'package:rowcraft/features/workout/workout_engine.dart';
import 'package:rowcraft/features/workout/workout_provider.dart';
import 'package:rowcraft/features/workout/workout_screen_compact.dart';
import 'package:rowcraft/models/pm5_data.dart';
import 'package:rowcraft/models/workout_segment.dart';

WorkoutSessionState _stubSession() {
  const segment = WorkoutSegment(
    durationType: DurationType.time,
    durationValue: 180, // 3:00
    targetIntensity: 90,
    targetStrokeRate: 28,
  );
  return const WorkoutSessionState(
    workoutTitle: 'Test Workout',
    expandedSegments: [segment],
    engineState: WorkoutEngineState(
      phase: WorkoutPhase.rowing,
      currentSegment: segment,
      segmentProgress: 0.25, // 45s elapsed, 2:15 remaining
    ),
    pm5Data: PM5Data(
      elapsedTime: Duration(minutes: 1),
      distance: 400,
      pace: 1100,
      strokeRate: 28,
      watts: 180,
      calories: 42,
      strokeCount: 30,
      intervalCount: 0,
    ),
    ftpWatts: 250,
  );
}

class _FakeBleNotifier extends BleNotifier {
  @override
  BleState build() => const BleState();
}

Widget _harness(Widget child) {
  return ProviderScope(
    overrides: [
      bleProvider.overrideWith(_FakeBleNotifier.new),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _pumpCompact(WidgetTester tester, Widget child) async {
  // Phone-sized surface so the compact layout has enough vertical room
  // for the hero section + stat grid + controls without overflow.
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_harness(child));
}

void main() {
  group('WorkoutScreenCompactBody', () {
    testWidgets('renders all 6 stat tile labels', (tester) async {
      await _pumpCompact(
        tester,
        WorkoutScreenCompactBody(
          session: _stubSession(),
          isLocked: false,
          onStart: () {},
          onPause: () {},
          onResume: () {},
          onStop: () {},
        ),
      );

      expect(find.text('SEGMENT'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('TARGET PACE'), findsOneWidget);
      expect(find.text('TARGET S/M'), findsOneWidget);
      expect(find.text('HR'), findsOneWidget);
      expect(find.text('DISTANCE'), findsOneWidget);

      // segment countdown: 25% elapsed → 75% remaining of 180s = 135s = 2:15
      expect(find.text('2:15'), findsOneWidget);
      // target SPM appears in the tile (and again in the HeroSection
      // current-SPM display since the stub data has strokeRate == target).
      expect(find.text('28'), findsWidgets);
      // distance (default tile state)
      expect(find.text('400m'), findsOneWidget);
    });

    testWidgets('tapping SEGMENT tile toggles countdown ↔ count-up',
        (tester) async {
      await _pumpCompact(
        tester,
        WorkoutScreenCompactBody(
          session: _stubSession(),
          isLocked: false,
          onStart: () {},
          onPause: () {},
          onResume: () {},
          onStop: () {},
        ),
      );

      // Starts as countdown: remaining 2:15
      expect(find.text('SEGMENT'), findsOneWidget);
      expect(find.text('2:15'), findsOneWidget);

      await tester.tap(find.text('SEGMENT'));
      await tester.pump();

      // Now count-up: 0:45 elapsed (25% of 180s)
      expect(find.text('ELAPSED'), findsOneWidget);
      expect(find.text('0:45'), findsOneWidget);

      await tester.tap(find.text('ELAPSED'));
      await tester.pump();

      // Back to countdown
      expect(find.text('SEGMENT'), findsOneWidget);
      expect(find.text('2:15'), findsOneWidget);
    });

    testWidgets('tile tap-cycles: TOTAL, TARGET PACE, HR, CALORIES',
        (tester) async {
      const segment = WorkoutSegment(
        durationType: DurationType.time,
        durationValue: 180,
        targetIntensity: 90,
        targetStrokeRate: 28,
      );
      const session = WorkoutSessionState(
        workoutTitle: 'Test',
        expandedSegments: [segment],
        engineState: WorkoutEngineState(
          phase: WorkoutPhase.rowing,
          currentSegment: segment,
          segmentProgress: 0.25,
          avgPace: 1080, // 1:48
          avgHeartRate: 155,
        ),
        pm5Data: PM5Data(
          elapsedTime: Duration(minutes: 1),
          distance: 412,
          pace: 1100,
          strokeRate: 28,
          watts: 180,
          calories: 42,
          heartRate: 162,
          strokeCount: 30,
          intervalCount: 0,
        ),
        ftpWatts: 250,
      );

      await _pumpCompact(
        tester,
        WorkoutScreenCompactBody(
          session: session,
          isLocked: false,
          onStart: () {},
          onPause: () {},
          onResume: () {},
          onStop: () {},
        ),
      );

      // TOTAL → REMAINING
      expect(find.text('TOTAL'), findsOneWidget);
      await tester.tap(find.text('TOTAL'));
      await tester.pump();
      expect(find.text('REMAINING'), findsOneWidget);
      // 180s segment, 25% done = 135s = 2:15 remaining (only one segment in stub)
      expect(find.text('2:15'), findsWidgets);

      // TARGET PACE → AVG PACE
      expect(find.text('TARGET PACE'), findsOneWidget);
      await tester.tap(find.text('TARGET PACE'));
      await tester.pump();
      expect(find.text('AVG PACE'), findsOneWidget);
      expect(find.text('1:48'), findsOneWidget);

      // HR → AVG HR
      expect(find.text('HR'), findsOneWidget);
      // current HR is 162
      expect(find.text('162'), findsOneWidget);
      await tester.tap(find.text('HR'));
      await tester.pump();
      expect(find.text('AVG HR'), findsOneWidget);
      expect(find.text('155'), findsOneWidget);

      // DISTANCE → CALORIES (default is distance)
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text(session.pm5Data.distanceFormatted), findsOneWidget);
      await tester.tap(find.text('DISTANCE'));
      await tester.pump();
      expect(find.text('CALORIES'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });
  });

  group('effectiveDisplayMode', () {
    testWidgets('defaults to compact on phone-sized screen', (tester) async {
      WorkoutDisplayMode? resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)), // phone
          child: Builder(
            builder: (context) {
              resolved = effectiveDisplayMode(null, context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, WorkoutDisplayMode.compact);
    });

    testWidgets('defaults to classic on tablet-sized screen', (tester) async {
      WorkoutDisplayMode? resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1024, 1366)), // tablet
          child: Builder(
            builder: (context) {
              resolved = effectiveDisplayMode(null, context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, WorkoutDisplayMode.classic);
    });

    testWidgets('respects stored preference over screen size',
        (tester) async {
      WorkoutDisplayMode? resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              resolved = effectiveDisplayMode(
                  WorkoutDisplayMode.classic, context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, WorkoutDisplayMode.classic);
    });
  });
}
