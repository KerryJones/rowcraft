import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/plan_progress.dart';
import '../models/training_plan.dart';
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
  final int? currentFtpWatts;
  final int? maxHeartRate;
  final double? weightKg;

  const Profile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.c2Linked = false,
    this.currentFtpWatts,
    this.maxHeartRate,
    this.weightKg,
  });

  Profile copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    bool? c2Linked,
    int? currentFtpWatts,
    int? maxHeartRate,
    double? weightKg,
  }) {
    return Profile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      c2Linked: c2Linked ?? this.c2Linked,
      currentFtpWatts: currentFtpWatts ?? this.currentFtpWatts,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      weightKg: weightKg ?? this.weightKg,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      c2Linked: (json['c2_linked'] as bool?) ?? false,
      currentFtpWatts: json['current_ftp_watts'] as int?,
      maxHeartRate: json['max_heart_rate'] as int?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'c2_linked': c2Linked,
      if (currentFtpWatts != null) 'current_ftp_watts': currentFtpWatts,
      if (maxHeartRate != null) 'max_heart_rate': maxHeartRate,
      if (weightKg != null) 'weight_kg': weightKg,
    };
  }
}

/// A single FTP test record.
class FtpRecord {
  final String id;
  final String userId;
  final DateTime testedAt;
  final int ftpWatts;
  final String testType; // 'ramp', '20min', 'manual'
  final String? sourceResultId;

  const FtpRecord({
    required this.id,
    required this.userId,
    required this.testedAt,
    required this.ftpWatts,
    required this.testType,
    this.sourceResultId,
  });

  factory FtpRecord.fromJson(Map<String, dynamic> json) {
    return FtpRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      testedAt: DateTime.parse(json['tested_at'] as String),
      ftpWatts: json['ftp_watts'] as int,
      testType: json['test_type'] as String,
      sourceResultId: json['source_result_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'tested_at': testedAt.toIso8601String(),
      'ftp_watts': ftpWatts,
      'test_type': testType,
      if (sourceResultId != null) 'source_result_id': sourceResultId,
    };
  }
}

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  String? get currentUserId => _client.auth.currentUser?.id;

  void _log(String method, Object error, [StackTrace? stack]) {
    dev.log('SupabaseService.$method failed: $error',
        name: 'rowcraft', error: error, stackTrace: stack);
  }

  // ── Workouts ──────────────────────────────────────────────────────────

  Future<List<Workout>> getWorkouts({
    bool? isPublic,
    String? authorId,
  }) async {
    try {
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
    } catch (e, stack) {
      _log('getWorkouts', e, stack);
      rethrow;
    }
  }

  Future<List<Workout>> getWorkoutsUpdatedSince(
    DateTime since, {
    bool? isPublic,
    String? authorId,
  }) async {
    try {
      var query = _client
          .from('workouts')
          .select()
          .gte('updated_at', since.toIso8601String());

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
    } catch (e, stack) {
      _log('getWorkoutsUpdatedSince', e, stack);
      rethrow;
    }
  }

  /// Fetches only workout IDs — used for delete detection during full sync.
  Future<List<String>> getWorkoutIds({bool? isPublic, String? authorId}) async {
    try {
      var query = _client.from('workouts').select('id');

      if (isPublic != null) {
        query = query.eq('is_public', isPublic);
      }
      if (authorId != null) {
        query = query.eq('author_id', authorId);
      }

      final response = await query;
      return (response as List<dynamic>)
          .map((e) => (e as Map<String, dynamic>)['id'] as String)
          .toList();
    } catch (e, stack) {
      _log('getWorkoutIds', e, stack);
      rethrow;
    }
  }

  Future<Workout> getWorkout(String id) async {
    try {
      final response =
          await _client.from('workouts').select().eq('id', id).single();
      return Workout.fromJson(response);
    } catch (e, stack) {
      _log('getWorkout($id)', e, stack);
      rethrow;
    }
  }

  Future<List<Workout>> getWorkoutsByIds(List<String> ids) async {
    try {
      final response = await _client
          .from('workouts')
          .select()
          .inFilter('id', ids);
      return (response as List<dynamic>)
          .map((e) => Workout.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _log('getWorkoutsByIds', e, stack);
      rethrow;
    }
  }

  Future<Workout> saveWorkout(Workout workout) async {
    try {
      final data = workout.toJson();
      final response = await _client
          .from('workouts')
          .upsert(data)
          .select()
          .single();
      return Workout.fromJson(response);
    } catch (e, stack) {
      _log('saveWorkout', e, stack);
      rethrow;
    }
  }

  Future<void> deleteWorkout(String id) async {
    try {
      await _client.from('workouts').delete().eq('id', id);
    } catch (e, stack) {
      _log('deleteWorkout($id)', e, stack);
      rethrow;
    }
  }

  Future<Workout> forkWorkout(String id) async {
    try {
      final original = await getWorkout(id);
      final userId = currentUserId;
      if (userId == null) throw StateError('Not authenticated');

      final now = DateTime.now();
      final forked = original.copyWith(
        id: '',
        authorId: userId,
        title: '${original.title} (fork)',
        isPublic: false,
        forkCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      await _client.rpc('increment_fork_count', params: {'workout_id': id});

      final response = await _client
          .from('workouts')
          .insert(forked.toJson()..remove('id'))
          .select()
          .single();
      return Workout.fromJson(response);
    } catch (e, stack) {
      _log('forkWorkout($id)', e, stack);
      rethrow;
    }
  }

  // ── Results ───────────────────────────────────────────────────────────

  Future<List<WorkoutResult>> getResults(String userId) async {
    try {
      final response = await _client
          .from('workout_results')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false);
      return (response as List<dynamic>)
          .map((e) => WorkoutResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _log('getResults($userId)', e, stack);
      rethrow;
    }
  }

  Future<WorkoutResult> saveResult(WorkoutResult result) async {
    try {
      final data = result.toJson();
      final response = await _client
          .from('workout_results')
          .upsert(data)
          .select()
          .single();
      return WorkoutResult.fromJson(response);
    } catch (e, stack) {
      _log('saveResult', e, stack);
      rethrow;
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────

  Future<Profile> getProfile() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw StateError('Not authenticated');

      final response =
          await _client.from('profiles').select().eq('id', userId).single();
      return Profile.fromJson(response);
    } catch (e, stack) {
      _log('getProfile', e, stack);
      rethrow;
    }
  }

  Future<void> updateProfile(Profile profile) async {
    try {
      await _client.from('profiles').upsert(profile.toJson());
    } catch (e, stack) {
      _log('updateProfile', e, stack);
      rethrow;
    }
  }

  /// Update just the current FTP on the profile.
  Future<void> updateProfileFtp(int ftpWatts) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw StateError('Not authenticated');
      await _client
          .from('profiles')
          .update({'current_ftp_watts': ftpWatts}).eq('id', userId);
    } catch (e, stack) {
      _log('updateProfileFtp', e, stack);
      rethrow;
    }
  }

  /// Update just the weight on the profile.
  Future<void> updateProfileWeight(double kg) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw StateError('Not authenticated');
      await _client
          .from('profiles')
          .update({'weight_kg': kg}).eq('id', userId);
    } catch (e, stack) {
      _log('updateProfileWeight', e, stack);
      rethrow;
    }
  }

  // ── FTP History ─────────────────────────────────────────────────────

  Future<List<FtpRecord>> getFtpHistory() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw StateError('Not authenticated');

      final response = await _client
          .from('ftp_history')
          .select()
          .eq('user_id', userId)
          .order('tested_at', ascending: false);
      return (response as List<dynamic>)
          .map((e) => FtpRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      _log('getFtpHistory', e, stack);
      rethrow;
    }
  }

  Future<FtpRecord> saveFtpRecord(FtpRecord record) async {
    try {
      final data = record.toJson();
      final response = await _client
          .from('ftp_history')
          .insert(data)
          .select()
          .single();
      return FtpRecord.fromJson(response);
    } catch (e, stack) {
      _log('saveFtpRecord', e, stack);
      rethrow;
    }
  }

  // ── Training Plans ─────────────────────────────────────────────────

  Future<List<TrainingPlan>> getTrainingPlans() async {
    try {
      final response = await _client
          .from('training_plans')
          .select()
          .order('created_at', ascending: true);
      return response
          .map((e) => TrainingPlan.fromJson(e))
          .toList();
    } catch (e, stack) {
      _log('getTrainingPlans', e, stack);
      rethrow;
    }
  }

  Future<TrainingPlan> getTrainingPlan(String id) async {
    try {
      final response = await _client
          .from('training_plans')
          .select()
          .eq('id', id)
          .single();
      return TrainingPlan.fromJson(response);
    } catch (e, stack) {
      _log('getTrainingPlan($id)', e, stack);
      rethrow;
    }
  }

  // ── Plan Progress ──────────────────────────────────────────────────

  Future<List<PlanProgress>> getUserPlanProgress() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw StateError('Not authenticated');

      final response = await _client
          .from('user_plan_progress')
          .select()
          .eq('user_id', userId)
          .order('last_viewed_at', ascending: false);
      return response
          .map((e) => PlanProgress.fromJson(e))
          .toList();
    } catch (e, stack) {
      _log('getUserPlanProgress', e, stack);
      rethrow;
    }
  }

  Future<PlanProgress?> getPlanProgress(String planId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw StateError('Not authenticated');

      final response = await _client
          .from('user_plan_progress')
          .select()
          .eq('user_id', userId)
          .eq('plan_id', planId)
          .maybeSingle();
      if (response == null) return null;
      return PlanProgress.fromJson(response);
    } catch (e, stack) {
      _log('getPlanProgress($planId)', e, stack);
      rethrow;
    }
  }

  /// Mark a plan session as completed.
  ///
  /// NOTE: This uses a read-modify-write pattern on the JSONB array.
  /// A concurrent write from another device could lose data. For v1 this
  /// is acceptable — a future improvement would use a Postgres RPC with
  /// atomic `jsonb || jsonb` append.
  Future<void> completePlanSession(
    String planId,
    int week,
    int session,
    String? resultId,
  ) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw StateError('Not authenticated');

      final now = DateTime.now().toIso8601String();
      final newEntry = CompletedSession(
        week: week,
        session: session,
        resultId: resultId,
        completedAt: DateTime.now(),
      ).toJson();

      // Try to get existing progress
      final existing = await getPlanProgress(planId);

      if (existing != null) {
        // Check if already completed to avoid duplicates
        if (existing.isCompleted(week, session)) return;

        final updated = [
          ...existing.completedSessions.map((cs) => cs.toJson()),
          newEntry,
        ];
        await _client
            .from('user_plan_progress')
            .update({
              'completed_sessions': updated,
              'last_viewed_at': now,
            })
            .eq('id', existing.id);
      } else {
        // Create new progress row
        await _client.from('user_plan_progress').insert({
          'user_id': userId,
          'plan_id': planId,
          'completed_sessions': [newEntry],
          'last_viewed_at': now,
        });
      }
    } catch (e, stack) {
      _log('completePlanSession', e, stack);
      rethrow;
    }
  }

  Future<void> touchPlanLastViewed(String planId) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw StateError('Not authenticated');

      final now = DateTime.now().toIso8601String();

      // Upsert: create progress row if it doesn't exist, otherwise update last_viewed_at
      await _client.from('user_plan_progress').upsert(
        {
          'user_id': userId,
          'plan_id': planId,
          'last_viewed_at': now,
        },
        onConflict: 'user_id,plan_id',
      );
    } catch (e, stack) {
      _log('touchPlanLastViewed($planId)', e, stack);
      rethrow;
    }
  }
}
