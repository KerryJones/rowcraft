import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/workout_result.dart';

const _plexoApiUrl = String.fromEnvironment(
  'PLEXO_API_URL',
  defaultValue: 'http://localhost:8000',
);
const _plexoApiKey = String.fromEnvironment('PLEXO_API_KEY');
const _plexoUserId = String.fromEnvironment('PLEXO_USER_ID', defaultValue: '');

final plexoServiceProvider = Provider<PlexoService>((ref) {
  return PlexoService();
});

/// Whether Plexo sync is enabled for the current user.
final plexoEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(plexoServiceProvider);
  return service.isEnabled();
});

/// Service for syncing workout results to the Plexo health platform.
///
/// Sends completed rowing workouts to Plexo's exercise endpoint
/// so the health coach agent has rowing data alongside other metrics.
/// Feature-gated to specific users via display_name check.
class PlexoService {
  final _client = Supabase.instance.client;

  /// Whether Plexo sync is enabled for the current user.
  ///
  /// Requires all three: API key configured, user ID configured,
  /// and the current user's display_name matches the allowlist.
  Future<bool> isEnabled() async {
    if (_plexoApiKey.isEmpty || _plexoUserId.isEmpty) {
      debugPrint('Plexo disabled: API key or user ID not configured');
      return false;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Plexo disabled: no authenticated user');
      return false;
    }

    try {
      final response = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .single();

      final displayName = response['display_name'];
      // Gated to Kerry's account until Plexo integration is broadly enabled.
      if (displayName != 'kerryjones21') {
        debugPrint('Plexo disabled: display_name "$displayName" not in allowlist');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Plexo disabled: error checking profile: $e');
      return false;
    }
  }

  /// Sync a workout result to Plexo as a rowing exercise session.
  ///
  /// Returns a record with `success` and an optional `error` message.
  Future<({bool success, String? error})> syncResult(
    WorkoutResult result,
  ) async {
    try {
      final body = jsonEncode([
        {
          'userId': _plexoUserId,
          'exerciseType': 'rowing',
          'startTime': result.startedAt.toUtc().toIso8601String(),
          'endTime': result.finishedAt.toUtc().toIso8601String(),
          'durationMinutes': (result.totalTime.inSeconds / 60.0).round(),
          'distance': result.totalDistance,
          'calories': result.calories.toDouble(),
          if (result.avgHeartRate != null) 'avgHeartRate': result.avgHeartRate,
          if (result.avgStrokeRate > 0) 'avgStrokeRate': result.avgStrokeRate,
          if (result.avgWatts > 0) 'avgWatts': result.avgWatts,
          if (result.avgSplit > 0) 'avgSplitSeconds': result.avgSplit / 10.0,
          'workoutName': result.displayName,
          'source': 'rowcraft',
        },
      ]);

      final response = await http.post(
        Uri.parse('$_plexoApiUrl/api/v1/health/exercise'),
        headers: {
          'Authorization': 'Bearer $_plexoApiKey',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (success: true, error: null);
        }
        return (success: false, error: 'API returned success=false');
      }

      return (
        success: false,
        error: 'HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('Plexo sync error: $e');
      return (success: false, error: '$e');
    }
  }
}
