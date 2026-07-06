import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/profile/profile_screen.dart'
    show c2LinkedProvider, stravaLinkedProvider;
import '../utils/app_log.dart';

/// Messenger key for snackbars shown outside a screen context (deep links).
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// App-level listener for OAuth callback deep links
/// (`com.rowcraft.app://login-callback`).
///
/// Lives above the router so integration callbacks are handled no matter
/// which screen is mounted when the browser redirects back — previously the
/// listener lived in the Profile screen and callbacks were dropped whenever
/// the user returned to a different screen.
class DeepLinkObserver extends ConsumerStatefulWidget {
  final Widget child;
  const DeepLinkObserver({super.key, required this.child});

  @override
  ConsumerState<DeepLinkObserver> createState() => _DeepLinkObserverState();
}

class _DeepLinkObserverState extends ConsumerState<DeepLinkObserver> {
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppLinks().uriLinkStream.listen(_onUri, onError: (Object e) {
      AppLog.warn('deeplink', 'Deep link stream error', e);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onUri(Uri uri) {
    if (uri.scheme != 'com.rowcraft.app' || uri.host != 'login-callback') {
      return;
    }
    final service = uri.queryParameters['service'];
    ref.invalidate(c2LinkedProvider);
    ref.invalidate(stravaLinkedProvider);
    final label = service == 'strava' ? 'Strava' : 'Concept2 Logbook';
    final messenger = rootScaffoldMessengerKey.currentState;
    if (uri.queryParameters['success'] == 'true') {
      messenger?.showSnackBar(SnackBar(content: Text('$label connected!')));
    } else {
      final error = uri.queryParameters['error'] ?? 'Connection failed';
      messenger?.showSnackBar(
        SnackBar(content: Text('$label connection failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
