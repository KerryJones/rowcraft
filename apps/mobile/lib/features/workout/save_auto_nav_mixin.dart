import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/sync_service.dart';
import 'workout_provider.dart';

/// Mixin for ConsumerState widgets that show a save progress overlay
/// and auto-navigate home after successful save.
mixin SaveAutoNavMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _autoNavTimer;
  bool _showSaveOverlay = false;

  bool get showSaveOverlay => _showSaveOverlay;

  void startSaveOverlay() {
    setState(() => _showSaveOverlay = true);
  }

  void handleSaveProgressChange(
      WorkoutSessionState? _, WorkoutSessionState session) {
    if (!_showSaveOverlay) return;

    if (_autoNavTimer != null &&
        (session.syncError != null ||
            session.saveProgress == SaveProgress.error)) {
      _autoNavTimer?.cancel();
      _autoNavTimer = null;
    }

    final c2Ok = session.c2SyncStatus == C2SyncStatus.synced ||
        session.c2SyncStatus == C2SyncStatus.notLinked;
    if (session.saveProgress == SaveProgress.done &&
        session.syncError == null &&
        c2Ok &&
        _autoNavTimer == null) {
      _autoNavTimer = Timer(const Duration(seconds: 5), _navIfQueueClean);
    }
  }

  /// Wait for the local sync queue to drain before navigating home.
  /// A background sync (lifecycle observer) can race with the final
  /// cleanup; if the queue is non-empty when the timer fires, reschedule
  /// instead of stranding the user on the save screen.
  Future<void> _navIfQueueClean() async {
    if (!mounted) return;
    final pending = await ref.read(syncServiceProvider).pendingCount;
    if (!mounted) return;
    if (pending > 0) {
      _autoNavTimer = Timer(const Duration(seconds: 3), _navIfQueueClean);
      return;
    }
    context.go('/');
  }

  void cancelAutoNavTimer() {
    _autoNavTimer?.cancel();
    _autoNavTimer = null;
  }
}
