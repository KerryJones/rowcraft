import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/features/workout/widgets/pulsing_heart_icon.dart';

void main() {
  group('PulsingHeartIcon', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

    Finder scaleInside() => find.descendant(
          of: find.byType(PulsingHeartIcon),
          matching: find.byType(ScaleTransition),
        );

    testWidgets('renders a heart icon with the given color', (tester) async {
      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red)));
      expect(tester.widget<Icon>(find.byIcon(Icons.favorite)).color,
          Colors.red);
    });

    testWidgets('renders a bare icon (no ScaleTransition) when bpm is null',
        (tester) async {
      await tester.pumpWidget(
          host(const PulsingHeartIcon(color: Colors.red, bpm: null)));
      expect(scaleInside(), findsNothing);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('renders a bare icon when bpm is zero or negative',
        (tester) async {
      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red, bpm: 0)));
      expect(scaleInside(), findsNothing);

      await tester.pumpWidget(
          host(const PulsingHeartIcon(color: Colors.red, bpm: -5)));
      expect(scaleInside(), findsNothing);
    });

    testWidgets('wraps the icon in a ScaleTransition when bpm is positive',
        (tester) async {
      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red, bpm: 60)));
      expect(scaleInside(), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      // Tear down so the AnimationController disposes before test teardown.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('starts animating when bpm transitions from null → positive',
        (tester) async {
      await tester.pumpWidget(
          host(const PulsingHeartIcon(color: Colors.red, bpm: null)));
      expect(scaleInside(), findsNothing);

      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red, bpm: 60)));
      expect(scaleInside(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'stops animating and returns to bare icon when bpm goes positive → null',
        (tester) async {
      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red, bpm: 60)));
      expect(scaleInside(), findsOneWidget);

      await tester.pumpWidget(
          host(const PulsingHeartIcon(color: Colors.red, bpm: null)));
      expect(scaleInside(), findsNothing,
          reason:
              'when bpm clears, the icon must render bare — not a frozen ScaleTransition');
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('returns to bare icon when bpm goes positive → zero',
        (tester) async {
      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red, bpm: 60)));
      expect(scaleInside(), findsOneWidget);

      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red, bpm: 0)));
      expect(scaleInside(), findsNothing);
    });

    testWidgets('keeps animating when bpm changes between positive values',
        (tester) async {
      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red, bpm: 60)));
      expect(scaleInside(), findsOneWidget);

      await tester.pumpWidget(
          host(const PulsingHeartIcon(color: Colors.red, bpm: 120)));
      expect(scaleInside(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'resumes animating on positive → null → positive (controller reuse)',
        (tester) async {
      // Allocate controller and scale.
      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red, bpm: 60)));
      expect(scaleInside(), findsOneWidget);

      // Stop and tear down the scale (controller is retained internally).
      await tester.pumpWidget(
          host(const PulsingHeartIcon(color: Colors.red, bpm: null)));
      expect(scaleInside(), findsNothing);

      // Re-arm with a new positive bpm — must rebuild the scale.
      await tester
          .pumpWidget(host(const PulsingHeartIcon(color: Colors.red, bpm: 72)));
      expect(scaleInside(), findsOneWidget,
          reason: 'controller-reuse path must rebuild _scale');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
