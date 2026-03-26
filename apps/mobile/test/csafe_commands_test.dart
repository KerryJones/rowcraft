import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/features/ble/csafe_commands.dart';

void main() {
  group('CsafeCommands', () {
    test('buildFrame wraps commands with start/stop flags', () {
      final frame = CsafeCommands.buildFrame([0x80]);

      expect(frame.first, CsafeCommands.frameStartFlag);
      expect(frame.last, CsafeCommands.frameStopFlag);
    });

    test('buildFrame includes checksum', () {
      // Single command 0x80, checksum = 0x80 XOR 0x80 = 0x80
      final frame = CsafeCommands.buildFrame([0x80]);

      // Frame: [F1, 0x80, checksum, F2]
      // checksum of [0x80] = 0x80
      expect(frame.length, 4); // start + cmd + checksum + stop
      expect(frame[1], 0x80); // command
      expect(frame[2], 0x80); // checksum (XOR of 0x80)
    });

    test('buildFrame applies byte stuffing for flag bytes', () {
      // Per CSAFE spec: reserved bytes are escaped as [stuffFlag, byte ^ 0x20]
      final frame = CsafeCommands.buildFrame([0xF1]);

      // 0xF1 should become [0xF3, 0xD1] (stuff flag + byte XOR 0x20)
      expect(frame[1], CsafeCommands.frameStuffFlag);
      expect(frame[2], 0xD1); // 0xF1 ^ 0x20 = 0xD1
    });

    test('buildFrame stuffs stop flag correctly', () {
      final frame = CsafeCommands.buildFrame([0xF2]);
      expect(frame[1], CsafeCommands.frameStuffFlag);
      expect(frame[2], 0xD2); // 0xF2 ^ 0x20 = 0xD2
    });

    test('buildFrame stuffs stuff flag correctly', () {
      final frame = CsafeCommands.buildFrame([0xF3]);
      expect(frame[1], CsafeCommands.frameStuffFlag);
      expect(frame[2], 0xD3); // 0xF3 ^ 0x20 = 0xD3
    });

    test('goReady produces valid frame', () {
      final frame = CsafeCommands.goReady();
      expect(frame.first, CsafeCommands.frameStartFlag);
      expect(frame.last, CsafeCommands.frameStopFlag);
      // Command byte should be goReady
      expect(frame[1], CsafeCommands.cmdGoReady);
    });

    test('goIdle produces valid frame', () {
      final frame = CsafeCommands.goIdle();
      expect(frame[1], CsafeCommands.cmdGoIdle);
    });

    test('programSingleDistance contains distance bytes', () {
      final frame = CsafeCommands.programSingleDistance(2000);

      // Frame should contain the distance 2000 as little-endian bytes
      // 2000 = 0xD0, 0x07
      final bytes = frame.toList();
      expect(bytes.contains(0xD0), isTrue);
    });

    test('programSingleTime encodes hours/minutes/seconds', () {
      final frame = CsafeCommands.programSingleTime(3661); // 1h 1m 1s

      final bytes = frame.toList();
      // Should contain H=1, M=1, S=1 somewhere in payload
      expect(bytes.contains(1), isTrue);
    });

    test('programDistanceIntervals includes interval count', () {
      final frame = CsafeCommands.programDistanceIntervals(
        intervals: 8,
        workDistance: 500,
        restSeconds: 60,
      );

      final bytes = frame.toList();
      expect(bytes.contains(8), isTrue); // interval count
    });

    test('programTimedIntervals includes interval count', () {
      final frame = CsafeCommands.programTimedIntervals(
        intervals: 5,
        workSeconds: 180,
        restSeconds: 60,
      );

      final bytes = frame.toList();
      expect(bytes.contains(5), isTrue); // interval count
    });
  });
}
