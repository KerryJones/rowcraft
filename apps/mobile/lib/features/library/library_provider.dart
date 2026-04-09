import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/workout.dart';
import '../../services/supabase_service.dart';
import '../../services/workout_repository.dart';
import '../../utils/pace_utils.dart' show kDefaultFtpWatts;
import '../../utils/workout_utils.dart';

enum LibrarySortOrder { newest, duration, mostForked }

enum DurationFilter { under30, from30to60, over60 }

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

/// Workouts for WOD selection. Network-first, falls back to cache on failure.
/// Separate from workoutLibraryProvider so the WOD can wait for fresh data
/// while the list renders instantly from cache.
final wodWorkoutsProvider = FutureProvider<List<Workout>>((ref) async {
  ref.watch(workoutRefreshTriggerProvider);
  final repo = ref.watch(workoutRepositoryProvider);
  // minInterval matches workoutLibraryProvider's background refresh window,
  // so concurrent open of both providers does not duplicate network calls.
  // refreshWorkouts already swallows network errors (returns null); the
  // outer try/catch guards against local-cache read failures so the WOD
  // slot never enters an error state — it degrades to an empty pool.
  try {
    final fresh = await repo.refreshWorkouts(
      isPublic: true,
      minInterval: const Duration(minutes: 5),
    );
    return fresh ?? await repo.getWorkouts(isPublic: true);
  } catch (_) {
    return const [];
  }
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

/// Filtered and sorted workouts based on search, type, tag, duration, zone, and sort order.
final filteredWorkoutsProvider = FutureProvider.family<
    List<Workout>,
    ({
      String? search,
      WorkoutType? type,
      String? tag,
      DurationFilter? duration,
      int? hrZone,
      LibrarySortOrder sort,
    })>((ref, filter) async {
  final allWorkouts = await ref.watch(workoutLibraryProvider.future);

  var filtered = allWorkouts;

  // Pre-compute durations once if needed for filter or sort (avoids O(n·segments) per comparison).
  final Map<String, int>? durationMap =
      (filter.duration != null || filter.sort == LibrarySortOrder.duration)
          ? {
              for (final w in allWorkouts)
                w.id: computeEstimatedTotalTime(w.segments, kDefaultFtpWatts),
            }
          : null;

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

  // Filter by duration (estimated total time using default FTP)
  if (filter.duration != null) {
    filtered = filtered.where((w) {
      final secs = durationMap![w.id]!;
      return switch (filter.duration!) {
        DurationFilter.under30 => secs < 1800,
        DurationFilter.from30to60 => secs >= 1800 && secs < 3600,
        DurationFilter.over60 => secs >= 3600,
      };
    }).toList();
  }

  // Filter by HR zone — workouts containing at least one segment in that zone
  if (filter.hrZone != null) {
    filtered = filtered
        .where((w) => w.segments.any((s) => s.targetHrZone == filter.hrZone))
        .toList();
  }

  // Sort
  final result = List.of(filtered);
  switch (filter.sort) {
    case LibrarySortOrder.newest:
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case LibrarySortOrder.duration:
      result.sort((a, b) => durationMap![a.id]!.compareTo(durationMap[b.id]!));
    case LibrarySortOrder.mostForked:
      result.sort((a, b) => b.forkCount.compareTo(a.forkCount));
  }

  return result;
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
