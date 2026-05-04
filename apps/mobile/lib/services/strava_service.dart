import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workout_result.dart';

/// Error that requires user action to resolve (e.g. reconnect Strava).
class StravaActionableException implements Exception {
  final String message;
  const StravaActionableException(this.message);
  @override
  String toString() => message;
}

const _webAppUrl = String.fromEnvironment(
  'WEB_APP_URL',
  defaultValue: 'http://localhost:3000',
);

final stravaServiceProvider = Provider<StravaService>((ref) {
  return StravaService();
});

/// Service for syncing workout results to Strava.
///
/// Uses the web app's API routes to handle OAuth and Strava uploads.
/// The web app stores tokens securely in the profiles table.
class StravaService {
  final _client = Supabase.instance.client;

  /// Whether the user has linked their Strava account.
  ///
  /// Checks the profiles table for a non-null strava_athlete_id.
  Future<bool> isLinked() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('profiles')
        .select('strava_athlete_id')
        .eq('id', userId)
        .single();

    return response['strava_athlete_id'] != null;
  }

  /// Initiate OAuth2 authentication with Strava.
  ///
  /// Opens the browser to the web app's Strava auth endpoint, which handles
  /// the OAuth redirect to Strava's authorization server. After the user
  /// authorizes, the web app exchanges the code for tokens, stores them,
  /// and redirects back to the mobile app via deep link.
  Future<void> authenticate() async {
    final session = _client.auth.currentSession;
    if (session == null) throw StateError('Not signed in');

    final authUrl = Uri.parse(
      '$_webAppUrl/api/strava/auth?source=mobile&token=${session.accessToken}',
    );

    await launchUrl(authUrl, mode: LaunchMode.externalApplication);
  }

  /// Sync a workout result to Strava via the web app's sync endpoint.
  ///
  /// Returns a record with `success` and an optional `error` message.
  /// Throws [StravaActionableException] on user-fixable errors so the
  /// sync service can surface the message to the user.
  Future<({bool success, String? error})> syncResult(
    WorkoutResult result,
  ) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return (success: false, error: 'No active session');
    }

    try {
      final response = await http.post(
        Uri.parse('$_webAppUrl/api/strava/sync'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'result_id': result.id,
        }),
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
        throw const StravaActionableException(
          'Strava token expired — reconnect in Profile',
        );
      }
      if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        final msg = data['error'] as String? ?? 'Validation error';
        throw StravaActionableException(msg);
      }

      return (
        success: false,
        error: 'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      assert(() { debugPrint('Strava sync error: $e'); return true; }());
      if (e is StravaActionableException) rethrow;
      return (success: false, error: '$e');
    }
  }

  /// Disconnect the Strava account by clearing tokens.
  Future<void> disconnect() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('profiles').update({
      'strava_athlete_id': null,
      'strava_access_token': null,
      'strava_refresh_token': null,
      'strava_token_expires_at': null,
    }).eq('id', userId);
  }
}
