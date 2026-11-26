// Widget tests for the compact workout layout:
// - renders 6 stat tiles with expected values
// - tap on SEGMENT tile flips label between countdown and count-up
// - effectiveDisplayMode picks compact for phones, classic for tablets

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rowcraft/features/ble/ble_provider.dart';
import 'package:rowcraft/features/workout/workout_engine.dart';
import 'package:rowcraft/features/workout/workout_provider.dart';
import 'package:rowcraft/features/workout/workout_screen_compact.dart';
import 'package:rowcraft/features/workout/widgets/workout_controls.dart';
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
      expect(find.text('TOTAL TIME'), findsOneWidget);
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

    testWidgets('tile tap-cycles: TOTAL TIME, TARGET PACE, HR, CALORIES',
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

      // Each tile starts in auto mode showing primary (since
      // _autoShowSecondary starts false). Tap cycle is auto → primary →
      // secondary → auto. First tap locks on primary (no visible change);
      // second tap advances to secondary.

      // TOTAL TIME → (lock primary) → REMAINING → (back to auto, primary)
      expect(find.text('TOTAL TIME'), findsOneWidget);
      await tester.tap(find.text('TOTAL TIME'));
      await tester.pump();
      expect(find.text('TOTAL TIME'), findsOneWidget); // primary, locked
      await tester.tap(find.text('TOTAL TIME'));
      await tester.pump();
      expect(find.text('REMAINING'), findsOneWidget);
      // 180s segment, 25% done = 135s = 2:15 remaining (only one segment in stub)
      expect(find.text('2:15'), findsWidgets);
      // Third tap returns to auto. _autoShowSecondary starts false, so the
      // visible variant snaps back to primary (TOTAL TIME).
      await tester.tap(find.text('REMAINING'));
      await tester.pump();
      expect(find.text('TOTAL TIME'), findsOneWidget);

      // TARGET PACE → (lock primary) → AVG PACE
      expect(find.text('TARGET PACE'), findsOneWidget);
      await tester.tap(find.text('TARGET PACE'));
      await tester.pump();
      expect(find.text('TARGET PACE'), findsOneWidget);
      await tester.tap(find.text('TARGET PACE'));
      await tester.pump();
      expect(find.text('AVG PACE'), findsOneWidget);
      expect(find.text('1:48'), findsOneWidget);

      // HR → (lock primary) → AVG HR
      expect(find.text('HR'), findsOneWidget);
      // current HR is 162
      expect(find.text('162'), findsOneWidget);
      await tester.tap(find.text('HR'));
      await tester.pump();
      expect(find.text('HR'), findsOneWidget);
      await tester.tap(find.text('HR'));
      await tester.pump();
      expect(find.text('AVG HR'), findsOneWidget);
      expect(find.text('155'), findsOneWidget);

      // DISTANCE → (lock primary) → CALORIES
      expect(find.text('DISTANCE'), findsOneWidget);
      expect(find.text(session.pm5Data.distanceFormatted), findsOneWidget);
      await tester.tap(find.text('DISTANCE'));
      await tester.pump();
      expect(find.text('DISTANCE'), findsOneWidget);
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
  group('WorkoutScreenCompactBody on a landscape phone', () {
    // Body sizes after the status bar and 40dp app bar: a 915x412 phone and
    // a short 740x360 one.
    for (final size in const [Size(915, 348), Size(740, 296)]) {
      for (final phase in const [
        WorkoutPhase.ready,
        WorkoutPhase.rowing,
        WorkoutPhase.paused,
      ]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()} '
            '${phase.name}: controls in side rail, no overflow',
            (tester) async {
          // view size, not setSurfaceSize — isLandscapePhone reads
          // MediaQuery, which only follows the view.
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final base = _stubSession();
          await tester.pumpWidget(_harness(WorkoutScreenCompactBody(
            session: base.copyWith(
              engineState: base.engineState.copyWith(phase: phase),
            ),
            isLocked: false,
            onStart: () {},
            onPause: () {},
            onResume: () {},
            onStop: () {},
          )));

          expect(tester.takeException(), isNull);
          // Rail hugs the right edge and spans the height rather than
          // sitting as a full-width bar along the bottom.
          final rail = tester.getRect(find.byType(WorkoutControls));
          expect(rail.right, size.width);
          expect(rail.width, lessThan(120));
          expect(rail.height, size.height);

          // Cycle glyph and page dots are dropped on landscape phones so the
          // labels fit untruncated. Only checked at the typical width: the
          // test font (Ahem) is far wider than Inter, so the short phone
          // would truncate here even though it doesn't on a device.
          if (size.width >= 900 && phase == WorkoutPhase.rowing) {
            for (final label in const [
              'SEGMENT', 'TOTAL TIME', 'TARGET PACE', 'TARGET S/M', 'HR',
              'DISTANCE',
            ]) {
              final paragraph =
                  tester.renderObject<RenderParagraph>(find.text(label));
              expect(paragraph.didExceedMaxLines, isFalse, reason: label);
            }
          }
        });
      }
    }
  });
}
