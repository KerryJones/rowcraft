import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/services/audio_service.dart';

void main() {
  group('AudioService WAV generation', () {
    test('generates a valid WAV header (RIFF/WAVE)', () {
      final bytes = AudioService.generateBeepWavForTest(
        frequency: 880,
        durationMs: 100,
      );

      // RIFF magic
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      // WAVE magic
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      // fmt chunk
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      // data chunk
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    });

    test('output length matches expected WAV size for given duration', () {
      const sampleRate = 22050;
      const durationMs = 100;
      final numSamples = (sampleRate * durationMs / 1000).round();
      final expectedSize = 44 + numSamples * 2; // 44-byte header + 16-bit mono

      final bytes = AudioService.generateBeepWavForTest(
        frequency: 880,
        durationMs: durationMs,
      );
      expect(bytes.length, expectedSize);
    });

    test('generates different buffers for low vs high beep', () {
      final low = AudioService.generateBeepWavForTest(
        frequency: 880,
        durationMs: 100,
      );
      final high = AudioService.generateBeepWavForTest(
        frequency: 1320,
        durationMs: 200,
      );
      expect(low.length, isNot(high.length));
    });
  });
}
