import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync_service.dart';

/// Drives [SyncService.syncPendingResults] from app lifecycle events.
///
/// Triggers a sync attempt on:
///   - app launch (the first build of [SyncLifecycleObserver])
///   - [AppLifecycleState.resumed] (returning from background)
///
/// Debounces to at most one attempt per [_minInterval] to avoid hammering
/// the network on quick foreground/background flips. Without this, the
/// SQLite queue is "aspirational" — pending rows just sit there until the
/// user happens to record another workout.
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;
  const SyncLifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  static const Duration _minInterval = Duration(seconds: 30);
  DateTime? _lastAttempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeSync();
    }
  }

  Future<void> _maybeSync() async {
    final now = DateTime.now();
    if (_lastAttempt != null && now.difference(_lastAttempt!) < _minInterval) {
      return;
    }
    _lastAttempt = now;
    try {
      await ref.read(syncServiceProvider).syncPendingResults();
    } catch (e) {
      debugPrint('SyncLifecycle: syncPendingResults threw: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
