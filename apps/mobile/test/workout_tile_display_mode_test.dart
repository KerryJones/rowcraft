import 'package:flutter_test/flutter_test.dart';

import 'package:rowcraft/features/workout/workout_screen_compact.dart';

void main() {
  group('advanceTileMode', () {
    test('auto advances to primary', () {
      expect(advanceTileMode(TileDisplayMode.auto), TileDisplayMode.primary);
    });

    test('primary advances to secondary', () {
      expect(
          advanceTileMode(TileDisplayMode.primary), TileDisplayMode.secondary);
    });

    test('secondary advances back to auto', () {
      expect(
          advanceTileMode(TileDisplayMode.secondary), TileDisplayMode.auto);
    });
  });

  group('tileShowsSecondary', () {
    test('auto follows the shared timer flag (false → primary)', () {
      expect(tileShowsSecondary(TileDisplayMode.auto, false), isFalse);
    });

    test('auto follows the shared timer flag (true → secondary)', () {
      expect(tileShowsSecondary(TileDisplayMode.auto, true), isTrue);
    });

    test('primary always shows primary regardless of timer flag', () {
      expect(tileShowsSecondary(TileDisplayMode.primary, false), isFalse);
      expect(tileShowsSecondary(TileDisplayMode.primary, true), isFalse);
    });

    test('secondary always shows secondary regardless of timer flag', () {
      expect(tileShowsSecondary(TileDisplayMode.secondary, false), isTrue);
      expect(tileShowsSecondary(TileDisplayMode.secondary, true), isTrue);
    });
  });
}
