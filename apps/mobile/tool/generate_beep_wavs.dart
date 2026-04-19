// Generates WAV asset files for workout countdown beeps.
// Run once: dart run tool/generate_beep_wavs.dart
// ignore_for_file: avoid_print, dangling_library_doc_comments
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final dir = Directory('assets/audio');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  File('assets/audio/beep_low.wav')
      .writeAsBytesSync(_singleToneWav(frequency: 880, durationMs: 100));
  print('wrote beep_low.wav');

  File('assets/audio/beep_high.wav')
      .writeAsBytesSync(_singleToneWav(frequency: 1320, durationMs: 200));
  print('wrote beep_high.wav');

  File('assets/audio/achievement.wav')
      .writeAsBytesSync(_achievementWav());
  print('wrote achievement.wav');
}

// ---------------------------------------------------------------------------
// WAV helpers
// ---------------------------------------------------------------------------

class _WavWriter {
  final ByteData buffer;
  int offset = 0;

  _WavWriter(int fileSize) : buffer = ByteData(fileSize);

  void writeString(String s) {
    for (var i = 0; i < s.length; i++) {
      buffer.setUint8(offset++, s.codeUnitAt(i));
    }
  }

  void writeUint32(int v) {
    buffer.setUint32(offset, v, Endian.little);
    offset += 4;
  }

  void writeUint16(int v) {
    buffer.setUint16(offset, v, Endian.little);
    offset += 2;
  }

  void writeHeader({required int sampleRate, required int dataSize}) {
    writeString('RIFF');
    writeUint32(44 + dataSize - 8);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1); // PCM
    writeUint16(1); // mono
    writeUint32(sampleRate);
    writeUint32(sampleRate * 2);
    writeUint16(2);
    writeUint16(16);
    writeString('data');
    writeUint32(dataSize);
  }

  void writeTone({
    required double frequency,
    required int numSamples,
    required int sampleRate,
    double volume = 0.6,
    double fadeFraction = 0.1,
  }) {
    final fadeLen = (numSamples * fadeFraction).round();
    for (var i = 0; i < numSamples; i++) {
      var envelope = 1.0;
      if (i < fadeLen) {
        envelope = i / fadeLen;
      } else if (i > numSamples - fadeLen) {
        envelope = (numSamples - i) / fadeLen;
      }
      final sample =
          (sin(2 * pi * frequency * i / sampleRate) * volume * envelope * 32767)
              .round()
              .clamp(-32768, 32767);
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }
  }

  void writeSilence(int numSamples) {
    for (var i = 0; i < numSamples; i++) {
      buffer.setInt16(offset, 0, Endian.little);
      offset += 2;
    }
  }

  Uint8List toBytes() => buffer.buffer.asUint8List();
}

Uint8List _singleToneWav({
  required double frequency,
  required int durationMs,
  int sampleRate = 22050,
  double volume = 0.6,
}) {
  final numSamples = (sampleRate * durationMs / 1000).round();
  final dataSize = numSamples * 2;
  final w = _WavWriter(44 + dataSize);
  w.writeHeader(sampleRate: sampleRate, dataSize: dataSize);
  w.writeTone(
    frequency: frequency,
    numSamples: numSamples,
    sampleRate: sampleRate,
    volume: volume,
  );
  return w.toBytes();
}

Uint8List _achievementWav({
  int sampleRate = 22050,
  double volume = 0.5,
}) {
  const tone1Freq = 523.25; // C5
  const tone2Freq = 659.25; // E5
  const tone1Ms = 200;
  const tone2Ms = 350;
  const gapMs = 50;

  final tone1Samples = (sampleRate * tone1Ms / 1000).round();
  final gapSamples = (sampleRate * gapMs / 1000).round();
  final tone2Samples = (sampleRate * tone2Ms / 1000).round();
  final totalSamples = tone1Samples + gapSamples + tone2Samples;
  final dataSize = totalSamples * 2;

  final w = _WavWriter(44 + dataSize);
  w.writeHeader(sampleRate: sampleRate, dataSize: dataSize);
  w.writeTone(
    frequency: tone1Freq,
    numSamples: tone1Samples,
    sampleRate: sampleRate,
    volume: volume,
    fadeFraction: 0.15,
  );
  w.writeSilence(gapSamples);
  w.writeTone(
    frequency: tone2Freq,
    numSamples: tone2Samples,
    sampleRate: sampleRate,
    volume: volume,
    fadeFraction: 0.15,
  );
  return w.toBytes();
}
