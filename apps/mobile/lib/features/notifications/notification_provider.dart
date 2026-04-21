import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_version_provider.dart';

const _lastSeenVersionKey = 'notifications_last_seen_version';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        read: read ?? this.read,
      );
}

class NotificationState {
  final List<AppNotification> notifications;

  const NotificationState({this.notifications = const []});

  int get unreadCount => notifications.where((n) => !n.read).length;

  NotificationState copyWith({List<AppNotification>? notifications}) =>
      NotificationState(notifications: notifications ?? this.notifications);
}

class NotificationNotifier extends AsyncNotifier<NotificationState> {
  @override
  Future<NotificationState> build() async {
    final currentVersion = await ref.watch(appVersionProvider.future);
    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getString(_lastSeenVersionKey);

    final notifications = <AppNotification>[];

    if (lastSeen != null && lastSeen != currentVersion) {
      notifications.add(AppNotification(
        id: 'update_$currentVersion',
        title: "What's new in v$currentVersion",
        body: 'RowCraft has been updated. Check out the latest improvements!',
        createdAt: DateTime.now(),
      ));
    }

    await prefs.setString(_lastSeenVersionKey, currentVersion);

    return NotificationState(notifications: notifications);
  }

  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(
      notifications: current.notifications.map((n) => n.copyWith(read: true)).toList(),
    ));
  }

  Future<void> dismiss(String id) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(
      notifications: current.notifications.where((n) => n.id != id).toList(),
    ));
  }
}

final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, NotificationState>(
  NotificationNotifier.new,
);
