import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/shell_app_bar_actions_provider.dart';
import '../app/theme.dart';
import '../features/notifications/notification_provider.dart';
import 'ble_status_button.dart';
import 'user_avatar.dart';

/// Shared AppBar used across all shell screens (Library, Plans, Profile).
class RowCraftAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool showProfileAvatar;

  const RowCraftAppBar({
    super.key,
    required this.title,
    this.showProfileAvatar = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extraActions = ref.watch(shellAppBarActionsProvider);
    final notifState = ref.watch(notificationProvider);
    final unreadCount = notifState.value?.unreadCount ?? 0;

    return AppBar(
      title: Text(title),
      actions: [
        ...extraActions,
        const BleStatusButton(),
        IconButton(
          onPressed: () => _showNotifications(context, ref),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            backgroundColor: RowCraftTheme.accentTeal,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        if (showProfileAvatar)
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: UserAvatar(radius: 16),
            ),
          ),
      ],
    );
  }

  void _showReleaseNotes(
      BuildContext context, WidgetRef ref, AppNotification notification) {
    if (!context.mounted) return;
    ref.read(notificationProvider.notifier).markAllRead();
    final content = notification.releaseNotes ?? notification.body;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SizedBox(
          width: double.maxFinite,
          child: Markdown(
            data: content,
            shrinkWrap: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium,
              h3: theme.textTheme.titleSmall,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext outerContext, WidgetRef ref) {
    final notifState = ref.read(notificationProvider).value;
    final notifications = notifState?.notifications ?? [];

    showModalBottomSheet(
      context: outerContext,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (notifications.any((n) => !n.read))
                      TextButton(
                        onPressed: () {
                          ref.read(notificationProvider.notifier).markAllRead();
                          Navigator.pop(context);
                        },
                        child: const Text('Mark all read'),
                      ),
                  ],
                ),
              ),
              if (notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No notifications',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: notifications
                        .map((n) => ListTile(
                              leading: Icon(
                                Icons.new_releases_outlined,
                                color: n.read
                                    ? Colors.grey
                                    : RowCraftTheme.accentTeal,
                              ),
                              title: Text(n.title),
                              subtitle: Text(n.body),
                              onTap: () {
                                Navigator.pop(context);
                                _showReleaseNotes(outerContext, ref, n);
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  ref
                                      .read(notificationProvider.notifier)
                                      .dismiss(n.id);
                                  Navigator.pop(context);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
