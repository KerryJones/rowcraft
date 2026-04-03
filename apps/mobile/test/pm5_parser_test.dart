import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/features/ble/pm5_parser.dart';
import 'package:rowcraft/models/pm5_data.dart';

void main() {
  group('PM5Parser', () {
    group('parseGeneralStatus (CE060031)', () {
      test('parses elapsed time and distance', () {
        // [0-2] elapsed time: 6000 centiseconds = 60s
        // [3-5] distance: 5000 tenths = 500.0m
        // [6-18] other fields (workout state, rowing state, etc.)
        final data = Uint8List(19);
        data[0] = 0x70;
        data[1] = 0x17;
        data[2] = 0x00; // 6000 centiseconds
        data[3] = 0x88;
        data[4] = 0x13;
        data[5] = 0x00; // 5000 tenths of meters

        final result =
            PM5Parser.parseGeneralStatus(data, const PM5Data.zero());

        expect(result.elapsedTime.inSeconds, 60);
        expect(result.distance, 500.0);
        // Should NOT set pace, strokeRate, watts, etc.
        expect(result.pace, 0);
        expect(result.strokeRate, 0);
        expect(result.watts, 0);
      });

      test('ignores payloads shorter than 6 bytes', () {
        final data = Uint8List(4);
        const current = PM5Data.zero();
        final result = PM5Parser.parseGeneralStatus(data, current);
        expect(identical(result, current), isTrue);
      });

      test('preserves fields from other characteristics', () {
        const current = PM5Data(
          elapsedTime: Duration.zero,
          distance: 0,
          pace: 1200,
          strokeRate: 24,
          watts: 180,
          calories: 25,
          strokeCount: 42,
          intervalCount: 3,
        );

        final data = Uint8List(19);
        data[0] = 0x70;
        data[1] = 0x17;
        data[2] = 0x00;
        data[3] = 0x88;
        data[4] = 0x13;
        data[5] = 0x00;

        final result = PM5Parser.parseGeneralStatus(data, current);
        // Updated fields
        expect(result.elapsedTime.inSeconds, 60);
        expect(result.distance, 500.0);
        // Preserved from current
        expect(result.pace, 1200);
        expect(result.strokeRate, 24);
        expect(result.watts, 180);
        expect(result.calories, 25);
        expect(result.strokeCount, 42);
        expect(result.intervalCount, 3);
      });
    });

    group('parseAdditionalStatus (CE060032)', () {
      test('parses stroke rate, heart rate, and pace', () {
        // [0-2] elapsed time
        // [3-4] speed
        // [5] stroke rate: 24
        // [6] heart rate: 145
        // [7-8] current pace: 12000 centiseconds = 2:00.0/500m
        // [9-10] average pace
        final data = Uint8List(17);
        data[5] = 24; // stroke rate
        data[6] = 145; // heart rate
        data[7] = 0xE0;
        data[8] = 0x2E; // 12000 centiseconds

        final result =
            PM5Parser.parseAdditionalStatus(data, const PM5Data.zero());

        expect(result.strokeRate, 24);
        expect(result.heartRate, 145);
        // 12000 centiseconds / 10 = 1200 tenths = 2:00.0/500m
        expect(result.pace, 1200);
      });

      test('handles invalid heart rate (255)', () {
        final data = Uint8List(17);
        data[5] = 22;
        data[6] = 255; // invalid HR

        final result =
            PM5Parser.parseAdditionalStatus(data, const PM5Data.zero());

        expect(result.heartRate, isNull);
        expect(result.strokeRate, 22);
      });

      test('handles zero heart rate', () {
        final data = Uint8List(17);
        data[6] = 0;

        final result =
            PM5Parser.parseAdditionalStatus(data, const PM5Data.zero());

        expect(result.heartRate, isNull);
      });

      test('preserves existing heart rate when new is invalid', () {
        const current = PM5Data(
          elapsedTime: Duration.zero,
          distance: 0,
          pace: 0,
          strokeRate: 0,
          watts: 0,
          calories: 0,
          heartRate: 145,
          strokeCount: 0,
          intervalCount: 0,
        );

        final data = Uint8List(17);
        data[6] = 255; // invalid

        final result = PM5Parser.parseAdditionalStatus(data, current);
        expect(result.heartRate, 145);
      });

      test('ignores short payloads', () {
        final data = Uint8List(8);
        const current = PM5Data.zero();
        final result = PM5Parser.parseAdditionalStatus(data, current);
        expect(identical(result, current), isTrue);
      });
    });

    group('parseAdditionalStatus2 (CE060033)', () {
      test('parses interval count, watts, and calories', () {
        final data = Uint8List(9);
        data[3] = 5; // interval count
        data[4] = 0xB4;
        data[5] = 0x00; // watts: 180
        data[6] = 0x19;
        data[7] = 0x00;
        data[8] = 0x00; // calories: 25

        final result =
            PM5Parser.parseAdditionalStatus2(data, const PM5Data.zero());

        expect(result.intervalCount, 5);
        expect(result.watts, 180);
        expect(result.calories, 25);
      });

      test('ignores short payloads', () {
        final data = Uint8List(6);
        const current = PM5Data.zero();
        final result = PM5Parser.parseAdditionalStatus2(data, current);
        expect(identical(result, current), isTrue);
      });
    });

    group('parseStrokeData (CE060035)', () {
      test('parses stroke count from stroke data payload', () {
        final data = Uint8List(20);
        data[16] = 0x96;
        data[17] = 0x00; // 150

        final result =
            PM5Parser.parseStrokeData(data, const PM5Data.zero());

        expect(result.strokeCount, 150);
      });

      test('ignores short payloads', () {
        final data = Uint8List(10);
        const current = PM5Data.zero();
        final result = PM5Parser.parseStrokeData(data, current);
        expect(identical(result, current), isTrue);
      });
    });
  });

  group('PM5Data formatting', () {
    test('paceFormatted shows M:SS.t', () {
      const data = PM5Data(
        elapsedTime: Duration.zero,
        distance: 0,
        pace: 1200,
        strokeRate: 0,
        watts: 0,
        calories: 0,
        strokeCount: 0,
        intervalCount: 0,
      );
      expect(data.paceFormatted, '2:00');
    });

    test('paceFormatted shows 1:45', () {
      const data = PM5Data(
        elapsedTime: Duration.zero,
        distance: 0,
        pace: 1055,
        strokeRate: 0,
        watts: 0,
        calories: 0,
        strokeCount: 0,
        intervalCount: 0,
      );
      expect(data.paceFormatted, '1:45');
    });

    test('paceFormatted shows placeholder for zero pace', () {
      const data = PM5Data.zero();
      expect(data.paceFormatted, '--:--');
    });

    test('distanceFormatted shows km for >= 1000m', () {
      const data = PM5Data(
        elapsedTime: Duration.zero,
        distance: 2500,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 0,
        strokeCount: 0,
        intervalCount: 0,
      );
      expect(data.distanceFormatted, '2.5km');
    });

    test('distanceFormatted shows m for < 1000m', () {
      const data = PM5Data(
        elapsedTime: Duration.zero,
        distance: 750,
        pace: 0,
        strokeRate: 0,
        watts: 0,
        calories: 0,
        strokeCount: 0,
        intervalCount: 0,
      );
      expect(data.distanceFormatted, '750m');
    });
  });
}
