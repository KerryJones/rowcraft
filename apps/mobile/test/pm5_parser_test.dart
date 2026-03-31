import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/features/ble/pm5_parser.dart';
import 'package:rowcraft/models/pm5_data.dart';

void main() {
  group('PM5Parser', () {
    group('parseGeneralStatus', () {
      test('parses 19-byte general status payload', () {
        // Build a 19-byte payload:
        // [0-2] elapsed time: 6000 centiseconds = 60s (0x70, 0x17, 0x00)
        // [3-5] distance: 5000 tenths = 500m (0x88, 0x13, 0x00)
        // [6]   workout type: 0
        // [7]   interval type: 0
        // [8-9] pace: 1200 tenths = 2:00.0/500m (0xB0, 0x04)
        // [10]  stroke rate: 24
        // [11]  heart rate: 145
        // [12]  reserved: 0
        // [13-14] watts: 180 (0xB4, 0x00)
        // [15-16] calories: 25 (0x19, 0x00)
        // [17]  interval count: 1
        // [18]  reserved: 0
        final data = Uint8List.fromList([
          0x70, 0x17, 0x00, // elapsed time: 6000 centiseconds
          0x88, 0x13, 0x00, // distance: 5000 tenths of meters
          0x00, // workout type
          0x00, // interval type
          0xB0, 0x04, // pace: 1200 tenths per 500m (2:00.0)
          24, // stroke rate
          145, // heart rate
          0x00, // reserved
          0xB4, 0x00, // watts: 180
          0x19, 0x00, // calories: 25
          0x01, // interval count
          0x00, // reserved
        ]);

        final result =
            PM5Parser.parseGeneralStatus(data, const PM5Data.zero());

        // Elapsed: 6000 centiseconds = 60,000 ms = 60s
        expect(result.elapsedTime.inSeconds, 60);

        // Distance: 5000 tenths = 500.0m
        expect(result.distance, 500.0);

        // Pace: 1200 tenths = 2:00.0/500m
        expect(result.pace, 1200);

        expect(result.strokeRate, 24);
        expect(result.heartRate, 145);
        expect(result.watts, 180);
        expect(result.calories, 25);
        expect(result.intervalCount, 1);
      });

      test('handles zero heart rate as null', () {
        final data = Uint8List(19); // All zeros
        data[10] = 22; // stroke rate

        final result =
            PM5Parser.parseGeneralStatus(data, const PM5Data.zero());

        expect(result.heartRate, isNull);
        expect(result.strokeRate, 22);
      });

      test('ignores payloads shorter than 19 bytes', () {
        final data = Uint8List(10);
        const current = PM5Data.zero();
        final result = PM5Parser.parseGeneralStatus(data, current);
        expect(identical(result, current), isTrue);
      });

      test('preserves existing data not in this characteristic', () {
        const current = PM5Data(
          elapsedTime: Duration.zero,
          distance: 0,
          pace: 0,
          strokeRate: 0,
          watts: 0,
          calories: 0,
          strokeCount: 42,
          intervalCount: 0,
        );

        final data = Uint8List(19);
        final result = PM5Parser.parseGeneralStatus(data, current);

        // strokeCount should be preserved from current
        expect(result.strokeCount, 42);
      });
    });

    group('parseStrokeData', () {
      test('parses stroke count from stroke data payload', () {
        final data = Uint8List(20);
        // Stroke count at bytes [16-17]: 150 (0x96, 0x00)
        data[16] = 0x96;
        data[17] = 0x00;

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

    group('parseAdditionalStatus', () {
      test('picks up heart rate when missing from general status', () {
        const current = PM5Data.zero(); // heartRate is null

        final data = Uint8List(12);
        data[5] = 152; // heart rate

        final result =
            PM5Parser.parseAdditionalStatus(data, current);

        expect(result.heartRate, 152);
      });

      test('does not overwrite existing heart rate', () {
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

        final data = Uint8List(12);
        data[5] = 160;

        final result =
            PM5Parser.parseAdditionalStatus(data, current);

        // Should keep existing 145, not overwrite with 160
        expect(result.heartRate, 145);
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
      expect(data.paceFormatted, '2:00.0');
    });

    test('paceFormatted shows 1:45.5', () {
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
      expect(data.paceFormatted, '1:45.5');
    });

    test('paceFormatted shows placeholder for zero pace', () {
      const data = PM5Data.zero();
      expect(data.paceFormatted, '--:--.--');
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
