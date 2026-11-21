// Widget tests for the Workout of the Day card on the library screen: it can
// be hidden until the next WOD rotates in, the hide survives in prefs, Undo
// brings it back, and a dismissal from a previous day doesn't hide today's.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rowcraft/features/ble/ble_provider.dart';
import 'package:rowcraft/features/history/history_provider.dart'
    show pendingSyncCountProvider;
import 'package:rowcraft/features/library/library_provider.dart';
import 'package:rowcraft/features/library/library_screen.dart';
import 'package:rowcraft/features/notifications/notification_provider.dart';
import 'package:rowcraft/features/plans/plans_provider.dart';
import 'package:rowcraft/models/workout.dart';
import 'package:rowcraft/models/workout_segment.dart';
import 'package:rowcraft/services/supabase_service.dart';
import 'package:rowcraft/widgets/wod_card.dart';

class _FakeSupabaseService extends Fake implements SupabaseService {
  @override
  String? get currentUserId => 'alice';
}

class _FakeBleNotifier extends BleNotifier {
  @override
  BleState build() => const BleState();
}

class _FakeNotificationNotifier extends NotificationNotifier {
  @override
  Future<NotificationState> build() async => const NotificationState();
}

final _wod = Workout(
  id: 'wod-1',
  authorId: 'coach',
  title: 'Pyramid Power',
  workoutType: WorkoutType.intervals,
  segments: const [
    WorkoutSegment(durationType: DurationType.distance, durationValue: 2000),
  ],
  isPublic: true,
  createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
  updatedAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
);

Widget _harness() {
  return ProviderScope(
    overrides: [
      supabaseServiceProvider.overrideWithValue(_FakeSupabaseService()),
      workoutLibraryProvider.overrideWith((_) async => [_wod]),
      wodWorkoutsProvider.overrideWith((_) async => [_wod]),
      trainingPlansProvider.overrideWith((_) async => const []),
      pendingSyncCountProvider.overrideWith((_) => Stream.value(0)),
      notificationProvider.overrideWith(_FakeNotificationNotifier.new),
      bleProvider.overrideWith(_FakeBleNotifier.new),
    ],
    child: const MaterialApp(home: LibraryScreen()),
  );
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_harness());
  await tester.pumpAndSettle();
}

void main() {
  group('Workout of the Day', () {
    testWidgets('X hides it until tomorrow and Undo restores it',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester);
      expect(find.byType(WodCard), findsOneWidget);

      await tester.tap(find.byTooltip('Hide until tomorrow'));
      await tester.pumpAndSettle();
      expect(find.byType(WodCard), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('wod_dismissed_day'), wodDay());

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.byType(WodCard), findsOneWidget);
      expect(prefs.getInt('wod_dismissed_day'), isNull);
    });

    testWidgets('stays hidden when dismissed earlier today', (tester) async {
      SharedPreferences.setMockInitialValues({'wod_dismissed_day': wodDay()});
      await _pump(tester);
      expect(find.byType(WodCard), findsNothing);
    });

    testWidgets('returns once the WOD rotates to a new day', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'wod_dismissed_day': wodDay() - 1});
      await _pump(tester);
      expect(find.byType(WodCard), findsOneWidget);
    });
  });
}
