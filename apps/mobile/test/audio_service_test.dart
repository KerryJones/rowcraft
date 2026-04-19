import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WAV asset files', () {
    test('beep_low.wav has valid RIFF/WAVE header', () {
      final bytes = File('assets/audio/beep_low.wav').readAsBytesSync();
      _expectValidWavHeader(bytes);
    });

    test('beep_high.wav has valid RIFF/WAVE header', () {
      final bytes = File('assets/audio/beep_high.wav').readAsBytesSync();
      _expectValidWavHeader(bytes);
    });

    test('achievement.wav has valid RIFF/WAVE header', () {
      final bytes = File('assets/audio/achievement.wav').readAsBytesSync();
      _expectValidWavHeader(bytes);
    });

    test('beep_low.wav matches expected size for 100ms at 22050Hz', () {
      final bytes = File('assets/audio/beep_low.wav').readAsBytesSync();
      const sampleRate = 22050;
      const durationMs = 100;
      final numSamples = (sampleRate * durationMs / 1000).round();
      final expectedSize = 44 + numSamples * 2;
      expect(bytes.length, expectedSize);
    });

    test('beep_high.wav matches expected size for 200ms at 22050Hz', () {
      final bytes = File('assets/audio/beep_high.wav').readAsBytesSync();
      const sampleRate = 22050;
      const durationMs = 200;
      final numSamples = (sampleRate * durationMs / 1000).round();
      final expectedSize = 44 + numSamples * 2;
      expect(bytes.length, expectedSize);
    });

    test('beep_low and beep_high are different sizes', () {
      final low = File('assets/audio/beep_low.wav').readAsBytesSync();
      final high = File('assets/audio/beep_high.wav').readAsBytesSync();
      expect(low.length, isNot(high.length));
    });
  });
}

void _expectValidWavHeader(Uint8List bytes) {
  expect(bytes.length, greaterThan(44));
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
  expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
}
