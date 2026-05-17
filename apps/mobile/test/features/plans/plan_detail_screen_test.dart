// Widget tests for SessionRow tap behavior:
// - tapping the status icon toggles completion (complete ↔ uncomplete)
//   and does NOT navigate
// - tapping the row body navigates to the workout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rowcraft/features/plans/plan_detail_screen.dart';
import 'package:rowcraft/models/plan_progress.dart';
import 'package:rowcraft/models/training_plan.dart';
import 'package:rowcraft/services/supabase_service.dart';

enum _Method { complete, uncomplete }

class _RecordedCall {
  final _Method method;
  final String planId;
  final int week;
  final int session;
  const _RecordedCall(this.method, this.planId, this.week, this.session);
}

class _FakeSupabaseService extends SupabaseService {
  // Disable the auto-refresh timer so the widget test doesn't fail with
  // "Timer is still pending after widget tree was disposed". The client is
  // intentionally not disposed at teardown: SupabaseClient.dispose() awaits
  // a JSON-isolate handshake that never completes inside FakeAsync, and
  // Realtime is lazy (we never subscribe), so no socket actually opens.
  _FakeSupabaseService()
      : super(SupabaseClient(
          'https://example.supabase.co',
          'fake-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final List<_RecordedCall> calls = [];

  @override
  Future<void> completePlanSession(
    String planId,
    int week,
    int session,
    String? resultId,
  ) async {
    calls.add(_RecordedCall(_Method.complete, planId, week, session));
  }

  @override
  Future<void> uncompletePlanSession(
    String planId,
    int week,
    int session,
  ) async {
    calls.add(_RecordedCall(_Method.uncomplete, planId, week, session));
  }

  @override
  Future<PlanProgress?> getPlanProgress(String planId) async => null;

  @override
  Future<List<PlanProgress>> getUserPlanProgress() async => [];
}

const _testPlanId = 'plan-test';
const _testWorkoutId = 'workout-test';

PlanSession _stubSession() => const PlanSession(
      dayLabel: 'Mon',
      workoutId: _testWorkoutId,
    );

class _NavRecorder {
  String? lastLocation;
}

Widget _harness({
  required _FakeSupabaseService fake,
  required Widget child,
  required _NavRecorder navRecorder,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/workout/:id',
        builder: (context, state) {
          navRecorder.lastLocation = state.uri.toString();
          return const Scaffold(body: Text('workout-page'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      supabaseServiceProvider.overrideWithValue(fake),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('SessionRow status icon', () {
    testWidgets('tap on incomplete row calls completePlanSession; no nav',
        (tester) async {
      final fake = _FakeSupabaseService();
      final nav = _NavRecorder();

      await tester.pumpWidget(_harness(
        fake: fake,
        navRecorder: nav,
        child: SessionRow(
          session: _stubSession(),
          weekNumber: 2,
          sessionIndex: 1,
          planId: _testPlanId,
          isCompleted: false,
          isNextUp: false,
        ),
      ));

      await tester.tap(find.byIcon(Icons.circle_outlined));
      await tester.pump();

      expect(fake.calls.length, 1);
      expect(fake.calls.single.method, _Method.complete);
      expect(fake.calls.single.planId, _testPlanId);
      expect(fake.calls.single.week, 2);
      expect(fake.calls.single.session, 1);
      expect(nav.lastLocation, isNull);
    });

    testWidgets('tap on completed row calls uncompletePlanSession; no nav',
        (tester) async {
      final fake = _FakeSupabaseService();
      final nav = _NavRecorder();

      await tester.pumpWidget(_harness(
        fake: fake,
        navRecorder: nav,
        child: SessionRow(
          session: _stubSession(),
          weekNumber: 3,
          sessionIndex: 0,
          planId: _testPlanId,
          isCompleted: true,
          isNextUp: false,
        ),
      ));

      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pump();

      expect(fake.calls.length, 1);
      expect(fake.calls.single.method, _Method.uncomplete);
      expect(fake.calls.single.planId, _testPlanId);
      expect(fake.calls.single.week, 3);
      expect(fake.calls.single.session, 0);
      expect(nav.lastLocation, isNull);
    });

    testWidgets('tap on row body navigates and does NOT toggle',
        (tester) async {
      final fake = _FakeSupabaseService();
      final nav = _NavRecorder();

      await tester.pumpWidget(_harness(
        fake: fake,
        navRecorder: nav,
        child: SessionRow(
          session: _stubSession(),
          weekNumber: 1,
          sessionIndex: 0,
          planId: _testPlanId,
          isCompleted: false,
          isNextUp: true,
        ),
      ));

      // Tap the session title text — outside the icon's 48px hit area.
      await tester.tap(find.textContaining('Mon'));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
      expect(nav.lastLocation, isNotNull);
      expect(nav.lastLocation, contains('/workout/$_testWorkoutId'));
      expect(nav.lastLocation, contains('plan=$_testPlanId'));
      expect(nav.lastLocation, contains('week=1'));
      expect(nav.lastLocation, contains('session=0'));
    });
  });
}
