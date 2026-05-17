import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _showRowingAnimationKey = 'workout_show_rowing_animation';

class AppSettings {
  final bool showRowingAnimation;

  const AppSettings({this.showRowingAnimation = true});

  AppSettings copyWith({bool? showRowingAnimation}) => AppSettings(
        showRowingAnimation: showRowingAnimation ?? this.showRowingAnimation,
      );
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      showRowingAnimation: prefs.getBool(_showRowingAnimationKey) ?? true,
    );
  }

  Future<void> setShowRowingAnimation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showRowingAnimationKey, value);
    final current = state.value ?? const AppSettings();
    state = AsyncData(current.copyWith(showRowingAnimation: value));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
