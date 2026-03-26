import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workout_result.dart';

final c2LogbookServiceProvider = Provider<C2LogbookService>((ref) {
  return C2LogbookService();
});

/// Service for syncing workout results to the Concept2 Online Logbook.
///
/// Uses the Supabase Edge Function (c2-logbook-sync) to handle OAuth
/// and result uploads. The edge function stores tokens securely in
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
  /// Opens the browser to the Supabase Edge Function which handles
  /// the OAuth redirect to Concept2's authorization server.
  /// Uses a random nonce as the OAuth state parameter (not the access token).
  Future<void> authenticate() async {
    final session = _client.auth.currentSession;
    if (session == null) return;

    // Cryptographically random state nonce for CSRF protection
    final random = Random.secure();
    final nonceBytes = List.generate(16, (_) => random.nextInt(256));
    final stateNonce = base64Url.encode(nonceBytes);
    final supabaseUrl = _client.rest.url.replaceAll('/rest/v1', '');
    final authUrl = Uri.parse(
      '$supabaseUrl/functions/v1/c2-logbook-sync/auth'
      '?state=$stateNonce',
    );

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// Handle the OAuth callback with the authorization code.
  ///
  /// This is called when the app receives the deep link callback
  /// from the C2 OAuth flow. It calls the edge function to exchange
  /// the code for tokens.
  Future<bool> handleCallback(String code) async {
    final session = _client.auth.currentSession;
    if (session == null) return false;

    try {
      final response = await _client.functions.invoke(
        'c2-logbook-sync/callback',
        body: {'code': code},
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.status == 200) {
        final data = jsonDecode(response.data as String);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      // Log but don't crash — caller handles false return
      assert(() { print('C2 callback error: $e'); return true; }());
      return false;
    }
  }

  /// Sync a workout result to the C2 Online Logbook.
  ///
  /// Calls the Supabase Edge Function which handles the API call
  /// to Concept2's servers using the stored OAuth tokens.
  Future<bool> syncResult(WorkoutResult result) async {
    final session = _client.auth.currentSession;
    if (session == null) return false;

    try {
      // Use toJson() as the single source of truth for field names and units
      final resultJson = result.toJson();
      final response = await _client.functions.invoke(
        'c2-logbook-sync/sync',
        body: resultJson,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.status == 200) {
        final data = jsonDecode(response.data as String);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      assert(() { print('C2 sync error: $e'); return true; }());
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
