import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workout_result.dart';

/// Error that requires user action to resolve (e.g. set weight in profile).
class C2ActionableException implements Exception {
  final String message;
  const C2ActionableException(this.message);
  @override
  String toString() => message;
}

const _webAppUrl = String.fromEnvironment(
  'WEB_APP_URL',
  defaultValue: 'http://localhost:3000',
);

final c2LogbookServiceProvider = Provider<C2LogbookService>((ref) {
  return C2LogbookService();
});

/// Service for syncing workout results to the Concept2 Online Logbook.
///
/// Uses the web app's API routes to handle OAuth and the C2 API
/// for result uploads. The web app stores tokens securely in
/// the profiles table.
class C2LogbookService {
  final _client = Supabase.instance.client;

  /// Whether the user has linked their C2 Logbook account.
  ///
  /// Checks the profiles table for a non-null c2_user_id.
  Future<bool> isLinked() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('profiles')
        .select('c2_user_id')
        .eq('id', userId)
        .single();

    return response['c2_user_id'] != null;
  }

  /// Get the linked C2 user ID, or null if not linked.
  Future<String?> getC2UserId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('profiles')
        .select('c2_user_id')
        .eq('id', userId)
        .single();

    return response['c2_user_id'] as String?;
  }

  /// Initiate OAuth2 authentication with the C2 Logbook.
  ///
  /// Opens the browser to the web app's C2 auth endpoint, which handles
  /// the OAuth redirect to Concept2's authorization server. After the user
  /// authorizes, the web app exchanges the code for tokens, stores them,
  /// and redirects back to the mobile app via deep link.
  ///
  /// Throws [StateError] if the user is not signed in or the URL cannot
  /// be launched.
  Future<void> authenticate() async {
    final session = _client.auth.currentSession;
    if (session == null) throw StateError('Not signed in');

    final authUrl = Uri.parse(
      '$_webAppUrl/api/c2/auth?source=mobile&token=${session.accessToken}',
    );

    await launchUrl(authUrl, mode: LaunchMode.externalApplication);
  }

  /// Sync a workout result to the C2 Online Logbook.
  ///
  /// Returns a record with `success` and an optional `error` message.
  /// Throws [C2ActionableException] on user-fixable errors (e.g. weight
  /// not set) so the sync service can surface the message to the user.
  Future<({bool success, String? error})> syncResult(
    WorkoutResult result,
  ) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return (success: false, error: 'No active session');
    }

    try {
      final response = await http.post(
        Uri.parse('$_webAppUrl/api/c2/sync'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'result_id': result.id}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (success: true, error: null);
        }
        return (success: false, error: 'API returned success=false');
      }

      // Surface actionable server errors so they reach the UI
      if (response.statusCode == 401) {
        throw const C2ActionableException(
          'C2 token expired — reconnect in Profile',
        );
      }
      if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        final msg = data['error'] as String? ?? 'Validation error';
        throw C2ActionableException(msg);
      }

      return (
        success: false,
        error: 'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      assert(() { debugPrint('C2 sync error: $e'); return true; }());
      if (e is C2ActionableException) rethrow;
      return (success: false, error: '$e');
    }
  }

  /// Disconnect the C2 Logbook account by clearing tokens.
  Future<void> disconnect() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('profiles').update({
      'c2_user_id': null,
      'c2_access_token': null,
      'c2_refresh_token': null,
    }).eq('id', userId);
  }
}
