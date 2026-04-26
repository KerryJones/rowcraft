import 'package:flutter/services.dart' show rootBundle;
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

  /// Full markdown content for the release notes dialog.
  final String? releaseNotes;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.releaseNotes,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        read: read ?? this.read,
        releaseNotes: releaseNotes,
      );
}

class NotificationState {
  final List<AppNotification> notifications;

  const NotificationState({this.notifications = const []});

  int get unreadCount => notifications.where((n) => !n.read).length;

  NotificationState copyWith({List<AppNotification>? notifications}) =>
      NotificationState(notifications: notifications ?? this.notifications);
}

/// Parse the CHANGELOG.md section for a specific version.
///
/// Returns the markdown content between the version header and the next
/// version header (or end of file). Strips the version header itself
/// and any leading/trailing whitespace.
String? _parseChangelogForVersion(String changelog, String version) {
  // release-please format: ## [0.3.4](url) (date)
  // Find the line starting with "## [<version>]"
  final versionHeader = '## [$version]';
  final startIndex = changelog.indexOf(versionHeader);
  if (startIndex < 0) return null;

  // Find the content after this header line
  final afterHeader = changelog.indexOf('\n', startIndex);
  if (afterHeader < 0) return null;

  // Find the next version header (## [)
  final nextVersionIndex = changelog.indexOf('\n## [', afterHeader);
  final section = nextVersionIndex >= 0
      ? changelog.substring(afterHeader, nextVersionIndex)
      : changelog.substring(afterHeader);

  final trimmed = section.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Build a short summary from the changelog section for the notification body.
String _buildSummary(String releaseNotes) {
  final lines = releaseNotes.split('\n');
  final bulletLines = <String>[];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('* ')) {
      // Extract just the description, strip the commit link
      var bullet = trimmed.substring(2).trim();
      // Remove trailing markdown link like ([abc1234](url))
      bullet = bullet.replaceAll(RegExp(r'\s*\(\[[^\]]+\]\([^)]+\)\)$'), '');
      bulletLines.add(bullet);
    }
  }

  if (bulletLines.isEmpty) return 'Check out the latest improvements!';
  if (bulletLines.length == 1) return bulletLines.first;
  return '${bulletLines.first} (+${bulletLines.length - 1} more)';
}

class NotificationNotifier extends AsyncNotifier<NotificationState> {
  @override
  Future<NotificationState> build() async {
    final currentVersion = await ref.watch(appVersionProvider.future);
    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getString(_lastSeenVersionKey);

    final notifications = <AppNotification>[];

    if (lastSeen != null && lastSeen != currentVersion) {
      // Load and parse CHANGELOG.md for actual release notes
      String? releaseNotes;
      String body = 'Check out the latest improvements!';
      try {
        final changelog = await rootBundle.loadString('CHANGELOG.md');
        releaseNotes = _parseChangelogForVersion(changelog, currentVersion);
        if (releaseNotes != null) {
          body = _buildSummary(releaseNotes);
        }
      } catch (_) {
        // Asset not found or parse error — fall back to generic message
      }

      notifications.add(AppNotification(
        id: 'update_$currentVersion',
        title: "What's new in v$currentVersion",
        body: body,
        createdAt: DateTime.now(),
        releaseNotes: releaseNotes,
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
