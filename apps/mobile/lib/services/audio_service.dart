import 'package:sound_effect/sound_effect.dart';

/// Service for playing workout audio cues (countdown beeps on segment transitions).
///
/// Uses the `sound_effect` package which plays via Android SoundPool / iOS
/// AVAudioPlayer in ambient mode — no audio focus is requested, so background
/// music is never paused or ducked.
class AudioService {
  AudioService._();
  static final instance = AudioService._();

  final _soundEffect = SoundEffect();
  bool _initialized = false;

  static const _beepLowId = 'beep_low';
  static const _beepHighId = 'beep_high';
  static const _achievementId = 'achievement';

  /// Initialize and pre-load audio assets. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    await _soundEffect.initialize(maxStreams: 2);
    await Future.wait([
      _soundEffect.load(_beepLowId, 'assets/audio/beep_low.wav'),
      _soundEffect.load(_beepHighId, 'assets/audio/beep_high.wav'),
      _soundEffect.load(_achievementId, 'assets/audio/achievement.wav'),
    ]);
    _initialized = true;
  }

  /// Play a countdown beep. [secondsLeft] = 3,2,1 plays a short beep;
  /// 0 plays a higher-pitched longer beep for segment start.
  Future<void> playCountdownBeep(int secondsLeft) async {
    await init();
    await _soundEffect.play(
      secondsLeft > 0 ? _beepLowId : _beepHighId,
    );
  }

  /// Play an ascending two-tone chime for achievements (FTP test completion).
  Future<void> playAchievement() async {
    await init();
    await _soundEffect.play(_achievementId);
  }
}
