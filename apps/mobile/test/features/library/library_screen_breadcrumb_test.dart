// Widget tests for the library breadcrumb: it shows the active category label
// (e.g. "My Workouts") as the current-level title, truncates a long label with
// an ellipsis without overflowing, and clearing returns to the tile grid.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rowcraft/features/history/history_provider.dart'
    show pendingSyncCountProvider;
import 'package:rowcraft/features/library/library_provider.dart';
import 'package:rowcraft/features/library/library_screen.dart';
import 'package:rowcraft/features/notifications/notification_provider.dart';
import 'package:rowcraft/features/plans/plans_provider.dart';
import 'package:rowcraft/models/workout.dart';
import 'package:rowcraft/models/workout_segment.dart';
import 'package:rowcraft/services/supabase_service.dart';

class _FakeSupabaseService extends Fake implements SupabaseService {
  @override
  String? get currentUserId => 'alice';
}

/// Silences the version-notification build (SharedPreferences / asset loads)
/// so the shared AppBar renders without platform channels.
class _FakeNotificationNotifier extends NotificationNotifier {
  @override
  Future<NotificationState> build() async => const NotificationState();
}

Workout _w(
  String id, {
  String authorId = 'alice',
  bool isPublic = false,
  List<String> tags = const [],
}) {
  final now = DateTime.parse('2026-01-01T00:00:00.000Z');
  return Workout(
    id: id,
    authorId: authorId,
    title: id,
    workoutType: WorkoutType.intervals,
    segments: const [
      WorkoutSegment(durationType: DurationType.distance, durationValue: 2000),
    ],
    tags: tags,
    isPublic: isPublic,
    createdAt: now,
    updatedAt: now,
  );
}

/// Renders the whole tile grid on screen so lazily-built tiles exist for the
/// finders. Callers reset via `addTearDown(tester.view.reset)`.
void _sizeToFitGrid(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
}

Widget _harness(List<Workout> workouts) {
  return ProviderScope(
    overrides: [
      supabaseServiceProvider.overrideWithValue(_FakeSupabaseService()),
      workoutLibraryProvider.overrideWith((_) async => workouts),
      wodWorkoutsProvider.overrideWith((_) async => const <Workout>[]),
      trainingPlansProvider.overrideWith((_) async => const []),
      pendingSyncCountProvider.overrideWith((_) => Stream.value(0)),
      notificationProvider.overrideWith(_FakeNotificationNotifier.new),
    ],
    child: const MaterialApp(home: LibraryScreen()),
  );
}

void main() {
  group('library breadcrumb', () {
    testWidgets('selecting "My Workouts" shows it in the breadcrumb',
        (tester) async {
      addTearDown(tester.view.reset);
      _sizeToFitGrid(tester);
      await tester.pumpWidget(_harness([_w('mine-1')]));
      await tester.pumpAndSettle();

      final tile = find.text('My Workouts');
      await tester.tap(tile);
      await tester.pumpAndSettle();

      // Grid is gone; the only "My Workouts" left is the breadcrumb title,
      // alongside the fixed "Workouts" back button.
      expect(find.text('My Workouts'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Workouts'), findsOneWidget);
    });

    testWidgets('clearing the breadcrumb returns to the tile grid',
        (tester) async {
      addTearDown(tester.view.reset);
      _sizeToFitGrid(tester);
      await tester.pumpWidget(_harness([_w('mine-1')]));
      await tester.pumpAndSettle();

      final tile = find.text('My Workouts');
      await tester.tap(tile);
      await tester.pumpAndSettle();

      // Back to grid via the back button (its arrow_back icon is unique).
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Tile grid is back — other category tiles are visible again.
      expect(find.text('Recovery'), findsOneWidget);
      expect(find.text('Tests & Benchmarks'), findsOneWidget);
    });

    testWidgets('a long active label truncates and does not overflow',
        (tester) async {
      addTearDown(tester.view.reset);
      _sizeToFitGrid(tester);

      // No matching workouts → empty-state list (safe to render narrow).
      await tester.pumpWidget(_harness(const []));
      await tester.pumpAndSettle();

      final tile = find.text('Tests & Benchmarks');
      await tester.tap(tile);
      await tester.pumpAndSettle();

      // Squeeze the row so the label must ellipsize; the fixed back button and
      // result count still fit.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');

      final label = tester.widget<Text>(find.text('Tests & Benchmarks'));
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(
        find.ancestor(
          of: find.text('Tests & Benchmarks'),
          matching: find.byType(Flexible),
        ),
        findsOneWidget,
        reason: 'label flexes so it truncates instead of overflowing',
      );
    });
  });
}
