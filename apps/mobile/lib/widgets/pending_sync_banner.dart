import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../features/history/history_provider.dart';

/// Thin banner shown at the top of the home screen when there are
/// locally-queued workouts that haven't synced yet. Tapping opens the
/// pending-sync screen for retry/discard actions.
class PendingSyncBanner extends ConsumerWidget {
  const PendingSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(pendingSyncCountProvider);
    final count = countAsync.value ?? 0;
    if (count == 0) return const SizedBox.shrink();

    final label = count == 1
        ? '1 workout waiting to sync'
        : '$count workouts waiting to sync';

    return Material(
      color: RowCraftTheme.primaryBlue.withValues(alpha: 0.15),
      child: InkWell(
        onTap: () => context.push('/pending-sync'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                size: 18,
                color: RowCraftTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label — tap to retry',
                  style: const TextStyle(
                    color: RowCraftTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: RowCraftTheme.primaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
