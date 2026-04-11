import 'dart:math';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart' hide AVAudioSessionCategory;

/// Service for playing workout audio cues (countdown beeps on segment transitions).
class AudioService {
  AudioService._();
  static final instance = AudioService._();

  final _player = AudioPlayer();
  Uint8List? _beepLow;
  Uint8List? _beepHigh;
  bool _initialized = false;

  /// Initialize audio buffers and configure audio session for ducking.
  /// Safe to call multiple times — only configures once.
  Future<void> init() async {
    _beepLow ??= _generateBeepWav(frequency: 880, durationMs: 100);
    _beepHigh ??= _generateBeepWav(frequency: 1320, durationMs: 200);
    if (_initialized) return;
    _initialized = true;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.notificationEvent,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));
  }

  /// Play a countdown beep. [secondsLeft] = 3,2,1 plays a short beep;
  /// 0 plays a higher-pitched longer beep for segment start.
  Future<void> playCountdownBeep(int secondsLeft) async {
    await init();
    final bytes = secondsLeft > 0 ? _beepLow! : _beepHigh!;
    await _player.stop();
    await _player.play(BytesSource(bytes));
  }

  void dispose() {
    _player.dispose();
  }

  /// Exposed for testing only. Use [playCountdownBeep] in production.
  static Uint8List generateBeepWavForTest({
    required double frequency,
    required int durationMs,
  }) =>
      _generateBeepWav(frequency: frequency, durationMs: durationMs);

  /// Generate a PCM WAV file in memory with a sine wave tone.
  static Uint8List _generateBeepWav({
    required double frequency,
    required int durationMs,
    int sampleRate = 22050,
    double volume = 0.6,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = numSamples * 2; // 16-bit mono
    final fileSize = 44 + dataSize;

    final buffer = ByteData(fileSize);
    var offset = 0;

    // RIFF header
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

    writeString('RIFF');
    writeUint32(fileSize - 8);
    writeString('WAVE');

    // fmt chunk
    writeString('fmt ');
    writeUint32(16); // chunk size
    writeUint16(1); // PCM format
    writeUint16(1); // mono
    writeUint32(sampleRate);
    writeUint32(sampleRate * 2); // byte rate
    writeUint16(2); // block align
    writeUint16(16); // bits per sample

    // data chunk
    writeString('data');
    writeUint32(dataSize);

    // Generate sine wave with fade-in/out envelope
    final fadeLen = (numSamples * 0.1).round();
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

    return buffer.buffer.asUint8List();
  }
}
