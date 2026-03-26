import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/workout.dart';
import '../models/workout_result.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

/// Profile data for the current user.
class Profile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final bool c2Linked;

  const Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.c2Linked = false,
  });

  Profile copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    bool? c2Linked,
  }) {
    return Profile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      c2Linked: c2Linked ?? this.c2Linked,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      c2Linked: (json['c2_linked'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'c2_linked': c2Linked,
    };
  }
}

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  String? get currentUserId => _client.auth.currentUser?.id;

  // ── Workouts ──────────────────────────────────────────────────────────

  Future<List<Workout>> getWorkouts({
    bool? isPublic,
    String? authorId,
  }) async {
    var query = _client.from('workouts').select();

    if (isPublic != null) {
      query = query.eq('is_public', isPublic);
    }
    if (authorId != null) {
      query = query.eq('author_id', authorId);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List<dynamic>)
        .map((e) => Workout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Workout> getWorkout(String id) async {
    final response =
        await _client.from('workouts').select().eq('id', id).single();
    return Workout.fromJson(response);
  }

  Future<Workout> saveWorkout(Workout workout) async {
    final data = workout.toJson();
    final response = await _client
        .from('workouts')
        .upsert(data)
        .select()
        .single();
    return Workout.fromJson(response);
  }

  Future<void> deleteWorkout(String id) async {
    await _client.from('workouts').delete().eq('id', id);
  }

  Future<Workout> forkWorkout(String id) async {
    final original = await getWorkout(id);
    final userId = currentUserId;
    if (userId == null) throw StateError('Not authenticated');

    final now = DateTime.now();
    final forked = original.copyWith(
      id: '', // Let Supabase generate the ID
      authorId: userId,
      title: '${original.title} (fork)',
      isPublic: false,
      forkCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    // Increment fork count on original
    await _client.rpc('increment_fork_count', params: {'workout_id': id});

    final response = await _client
        .from('workouts')
        .insert(forked.toJson()..remove('id'))
        .select()
        .single();
    return Workout.fromJson(response);
  }

  // ── Results ───────────────────────────────────────────────────────────

  Future<List<WorkoutResult>> getResults(String userId) async {
    final response = await _client
        .from('workout_results')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: false);
    return (response as List<dynamic>)
        .map((e) => WorkoutResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkoutResult> saveResult(WorkoutResult result) async {
    final data = result.toJson();
    final response = await _client
        .from('workout_results')
        .upsert(data)
        .select()
        .single();
    return WorkoutResult.fromJson(response);
  }

  // ── Profile ───────────────────────────────────────────────────────────

  Future<Profile> getProfile() async {
    final userId = currentUserId;
    if (userId == null) throw StateError('Not authenticated');

    final response =
        await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(response);
  }

  Future<void> updateProfile(Profile profile) async {
    await _client.from('profiles').upsert(profile.toJson());
  }
}
