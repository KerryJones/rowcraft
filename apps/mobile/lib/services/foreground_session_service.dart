import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_log.dart';

/// Entry point for the foreground task isolate. The handler does no work —
/// the service exists solely to hold foreground priority so Android keeps
/// the BLE connection and the main-isolate workout engine alive while the
/// app is backgrounded or the screen is locked.
@pragma('vm:entry-point')
void workoutSessionTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_WorkoutSessionTaskHandler());
}

class _WorkoutSessionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Keeps a workout session alive while the app is in the background.
///
/// Abstract so the workout provider can be tested with a fake.
abstract class ForegroundSessionService {
  /// Ask for notification permission (Android 13+) so the foreground
  /// service notification is visible. Call from the UI before a workout
  /// starts — the service itself runs regardless of the outcome.
  Future<void> requestPermission();

  /// Start the foreground service for an active workout.
  Future<void> start({required String workoutTitle});

  /// Update the notification text (e.g. current segment).
  Future<void> update({required String text});

  /// Stop the foreground service.
  Future<void> stop();
}

/// Real implementation backed by `flutter_foreground_task`.
///
/// Uses the `connectedDevice` service type (Android 14+ requirement) —
/// valid because a workout session always holds a BLE connection to the
/// PM5 and/or an HR strap.
class FlutterForegroundSessionService implements ForegroundSessionService {
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'workout_session',
        channelName: 'Workout Session',
        channelDescription:
            'Keeps your workout running while the screen is off or the app '
            'is in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
    _initialized = true;
  }

  @override
  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (e) {
      AppLog.warn('fgs', 'requestPermission failed', e);
    }
  }

  @override
  Future<void> start({required String workoutTitle}) async {
    if (!Platform.isAndroid) return;
    try {
      _ensureInitialized();
      if (await FlutterForegroundTask.isRunningService) return;
      final result = await FlutterForegroundTask.startService(
        serviceTypes: [ForegroundServiceTypes.connectedDevice],
        serviceId: 300,
        notificationTitle:
            workoutTitle.isNotEmpty ? workoutTitle : 'Workout in progress',
        notificationText: 'Recording workout — tap to return',
        callback: workoutSessionTaskCallback,
      );
      if (result is ServiceRequestFailure) {
        AppLog.warn('fgs', 'start failed: ${result.error}');
      }
    } catch (e) {
      // Never let foreground-service issues break the workout itself.
      AppLog.warn('fgs', 'start failed', e);
    }
  }

  @override
  Future<void> update({required String text}) async {
    if (!Platform.isAndroid) return;
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.updateService(notificationText: text);
    } catch (e) {
      AppLog.warn('fgs', 'update failed', e);
    }
  }

  @override
  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.stopService();
    } catch (e) {
      AppLog.warn('fgs', 'stop failed', e);
    }
  }
}

/// Global foreground session service instance.
final foregroundSessionServiceProvider =
    Provider<ForegroundSessionService>((ref) {
  return FlutterForegroundSessionService();
});
