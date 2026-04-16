import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      _autoNavTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) context.go('/');
      });
    }
  }

  void cancelAutoNavTimer() {
    _autoNavTimer?.cancel();
    _autoNavTimer = null;
  }
}
