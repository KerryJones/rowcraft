import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workout_result.dart';

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
  Future<void> authenticate() async {
    final session = _client.auth.currentSession;
    if (session == null) return;

    final authUrl = Uri.parse(
      '$_webAppUrl/api/c2/auth?source=mobile&token=${session.accessToken}',
    );

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// Sync a workout result to the C2 Online Logbook.
  ///
  /// Calls the web app's sync endpoint which handles the API call
  /// to Concept2's servers using the stored OAuth tokens.
  Future<bool> syncResult(WorkoutResult result) async {
    final session = _client.auth.currentSession;
    if (session == null) return false;

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
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      assert(() { debugPrint('C2 sync error: $e'); return true; }());
      return false;
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
