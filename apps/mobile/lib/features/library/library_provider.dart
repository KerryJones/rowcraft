import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/workout.dart';
import '../../services/supabase_service.dart';
import '../../services/workout_repository.dart';

/// Increment to force a library refresh (e.g. pull-to-refresh).
final workoutRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// All public workouts, served from cache.
///
/// Returns cached workouts immediately. If the cache is non-empty, a background
/// refresh runs silently. If the cache is empty (first launch), waits for the
/// network before returning.
final workoutLibraryProvider = FutureProvider<List<Workout>>((ref) async {
  // Re-run when refresh is triggered.
  ref.watch(workoutRefreshTriggerProvider);

  final repo = ref.watch(workoutRepositoryProvider);
  final cached = await repo.getWorkouts(isPublic: true);

  if (cached.isNotEmpty) {
    // Return cache immediately; refresh in background.
    // minInterval prevents a redundant network call when pull-to-refresh
    // has just run and re-triggered the provider.
    repo
        .refreshWorkouts(
          isPublic: true,
          minInterval: const Duration(minutes: 5),
        )
        .ignore();
    return cached;
  }

  // First launch or empty cache — wait for network.
  final fresh = await repo.refreshWorkouts(isPublic: true);
  return fresh ?? [];
});

/// Workouts authored by the current user.
final myWorkoutsProvider = FutureProvider<List<Workout>>((ref) async {
  ref.watch(workoutRefreshTriggerProvider);

  final service = ref.watch(supabaseServiceProvider);
  final userId = service.currentUserId;
  if (userId == null) return [];

  final repo = ref.watch(workoutRepositoryProvider);
  final cached = await repo.getWorkouts(authorId: userId);

  if (cached.isNotEmpty) {
    repo
        .refreshWorkouts(
          authorId: userId,
          minInterval: const Duration(minutes: 5),
        )
        .ignore();
    return cached;
  }

  final fresh = await repo.refreshWorkouts(authorId: userId);
  return fresh ?? [];
});

/// Filtered workouts based on search query, type, and tag.
final filteredWorkoutsProvider = FutureProvider.family<
    List<Workout>,
    ({String? search, WorkoutType? type, String? tag})>((ref, filter) async {
  final allWorkouts = await ref.watch(workoutLibraryProvider.future);

  var filtered = allWorkouts;

  // Filter by search query
  if (filter.search != null && filter.search!.isNotEmpty) {
    final query = filter.search!.toLowerCase();
    filtered = filtered.where((w) {
      return w.title.toLowerCase().contains(query) ||
          w.description.toLowerCase().contains(query) ||
          w.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();
  }

  // Filter by workout type
  if (filter.type != null) {
    filtered = filtered.where((w) => w.workoutType == filter.type).toList();
  }

  // Filter by tag
  if (filter.tag != null) {
    filtered = filtered.where((w) => w.tags.contains(filter.tag)).toList();
  }

  return filtered;
});

/// All unique tags across all workouts, for filter chips.
final allTagsProvider = FutureProvider<List<String>>((ref) async {
  final workouts = await ref.watch(workoutLibraryProvider.future);
  final tags = <String>{};
  for (final workout in workouts) {
    tags.addAll(workout.tags);
  }
  return tags.toList()..sort();
});

/// Similar workouts based on tag overlap. Excludes the source workout.
/// Returns top 4 matches sorted by overlap count, then fork count.
final similarWorkoutsProvider = FutureProvider.family<List<Workout>,
    ({String workoutId, List<String> tags})>((ref, params) async {
  if (params.tags.isEmpty) return [];

  final allWorkouts = await ref.watch(workoutLibraryProvider.future);
  final tagSet = params.tags.toSet();

  final scored = <(Workout, int)>[];
  for (final w in allWorkouts) {
    if (w.id == params.workoutId) continue;
    final overlap = w.tags.where(tagSet.contains).length;
    if (overlap > 0) scored.add((w, overlap));
  }

  scored.sort((a, b) {
    final cmp = b.$2.compareTo(a.$2);
    if (cmp != 0) return cmp;
    return b.$1.forkCount.compareTo(a.$1.forkCount);
  });

  return scored.take(4).map((e) => e.$1).toList();
});
