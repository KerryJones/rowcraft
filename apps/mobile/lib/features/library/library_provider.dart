import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../models/workout.dart';
import '../../services/supabase_service.dart';
import '../../services/workout_repository.dart';
import '../../utils/pace_utils.dart' show kDefaultFtpWatts;
import '../../utils/workout_utils.dart';
import '../auth/auth_provider.dart' show currentUserProvider;
import '../profile/profile_screen.dart' show profileProvider;

enum LibrarySortOrder { newest, duration, mostForked }

enum DurationFilter { under30, from30to60, over60 }

enum DistanceFilter { under2k, from2to5k, from5to10k, over10k }

/// Collection key → tag set. Any-tag-overlap filters the workout in.
/// Mirrors the web `COLLECTION_CATEGORIES` list in category-cards.tsx.
const Map<String, Set<String>> kCollectionTags = {
  'pete-plan': {'pete-plan'},
  'ftp-builder': {'ftp-builder'},
  '2k-race-prep': {'2k-race-prep'},
  'return-to-rowing': {'return-to-rowing'},
  'wods': {'wod', 'challenge'},
  'tests': {'test', 'benchmark'},
};

/// Tags that identify plan-specific workouts. Excluded from general
/// library browsing (shown when the user selects the plan's collection tile).
/// Keep in sync with PLAN_TAGS in apps/web/src/app/workouts/workouts-client.tsx.
const Set<String> kPlanTags = {
  'pete-plan',
  'ftp-builder',
  '2k-race-prep',
  'return-to-rowing',
};

/// HR zone → workout tag. Matches the web category card keys in
/// apps/web/src/components/ui/category-cards.tsx (Recovery, Aerobic, Tempo,
/// Threshold, VO2max). The category chip filters on these tags rather than
/// on segment-level `targetHrZone`, mirroring web behavior.
const Map<int, String> kZoneTags = {
  1: 'recovery',
  2: 'aerobic',
  3: 'tempo',
  4: 'threshold',
  5: 'vo2max',
};

/// Increment to force a library refresh (e.g. pull-to-refresh).
final workoutRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// All workouts visible to the current user: public + user-owned (private
/// included). Mirrors web's `is_public.eq.true,author_id.eq.<uid>` OR clause
/// by merging two repository calls and de-duping by id. Re-fires on auth
/// state change via `currentUserProvider` so private workouts appear/vanish
/// when the user signs in or out.
final workoutLibraryProvider = FutureProvider<List<Workout>>((ref) async {
  // Re-run when refresh is triggered, and when auth state changes.
  ref.watch(workoutRefreshTriggerProvider);
  final userId = ref.watch(currentUserProvider)?.id;
  final repo = ref.watch(workoutRepositoryProvider);

  List<Workout> merge(List<Workout> public, List<Workout> own) {
    if (own.isEmpty) return public;
    final seen = <String>{};
    final out = <Workout>[];
    for (final w in public) {
      if (seen.add(w.id)) out.add(w);
    }
    for (final w in own) {
      if (seen.add(w.id)) out.add(w);
    }
    return out;
  }

  final (cachedPublic, cachedOwn) = await (
    repo.getWorkouts(isPublic: true),
    userId == null
        ? Future.value(const <Workout>[])
        : repo.getWorkouts(authorId: userId),
  ).wait;

  // Cache short-circuit only when both halves the current user expects are
  // present. For signed-in users that means BOTH public AND own caches must
  // be populated — otherwise the user could see a half-populated library
  // (e.g. just signed in: public cached, own empty → fetch own synchronously
  // so private workouts appear in the first render, not after pull-to-refresh).
  final ownReady = userId == null || cachedOwn.isNotEmpty;
  if (cachedPublic.isNotEmpty && ownReady) {
    // Return cache immediately; refresh both lists in the background.
    // minInterval prevents a redundant network call when pull-to-refresh
    // has just run and re-triggered the provider.
    repo
        .refreshWorkouts(
          isPublic: true,
          minInterval: const Duration(minutes: 5),
        )
        .ignore();
    if (userId != null) {
      repo
          .refreshWorkouts(
            authorId: userId,
            minInterval: const Duration(minutes: 5),
          )
          .ignore();
    }
    return merge(cachedPublic, cachedOwn);
  }

  // First launch, empty cache, or post-sign-in — fetch both in parallel so
  // signed-in cold start is no slower than anonymous cold start.
  final (freshPublic, freshOwn) = await (
    repo.refreshWorkouts(isPublic: true),
    userId == null
        ? Future<List<Workout>?>.value(const <Workout>[])
        : repo.refreshWorkouts(authorId: userId),
  ).wait;
  return merge(freshPublic ?? cachedPublic, freshOwn ?? cachedOwn);
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

/// Filtered and sorted workouts based on search, type, tag, duration, distance,
/// zone, collection, mine, and sort order.
final filteredWorkoutsProvider = FutureProvider.family<
    List<Workout>,
    ({
      String? search,
      WorkoutType? type,
      String? tag,
      DurationFilter? duration,
      DistanceFilter? distance,
      int? hrZone,
      String? collectionKey,
      bool mine,
      LibrarySortOrder sort,
    })>((ref, filter) async {
  final allWorkouts = await ref.watch(workoutLibraryProvider.future);
  final profile = ref.watch(profileProvider);
  final ftpWatts = profile.value?.currentFtpWatts ?? kDefaultFtpWatts;

  var filtered = allWorkouts;

  // Exclude plan-specific workouts unless the user explicitly selected
  // a plan collection (e.g., tapped the "Pete Plan" tile).
  if (filter.collectionKey == null ||
      !kPlanTags.contains(filter.collectionKey)) {
    filtered =
        filtered.where((w) => !w.tags.any(kPlanTags.contains)).toList();
  }

  // Pre-compute durations once if needed for filter or sort (avoids O(n·segments) per comparison).
  final Map<String, int>? durationMap =
      (filter.duration != null || filter.sort == LibrarySortOrder.duration)
          ? {
              for (final w in filtered)
                w.id: computeEstimatedTotalTime(w.segments, ftpWatts),
            }
          : null;

  // Pre-compute total distance per workout when a distance filter is active.
  // null means the workout has no distance-based segments.
  final Map<String, double?>? distanceMap = filter.distance != null
      ? {
          for (final w in filtered) w.id: computeTotalDistance(w.segments),
        }
      : null;

  // Filter by search query with relevance scoring.
  // Tag matches rank highest, then title, then description.
  Map<String, int>? searchScores;
  if (filter.search != null && filter.search!.isNotEmpty) {
    final query = filter.search!.toLowerCase();
    searchScores = {};
    filtered = filtered.where((w) {
      var score = 0;
      if (w.tags.any((t) => t.toLowerCase().contains(query))) score += 3;
      if (w.title.toLowerCase().contains(query)) score += 2;
      if (w.description.toLowerCase().contains(query)) score += 1;
      if (score > 0) {
        searchScores![w.id] = score;
        return true;
      }
      return false;
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

  // Filter by total distance. Time-only workouts (null total distance) are
  // excluded when any distance bucket is active.
  if (filter.distance != null) {
    filtered = filtered.where((w) {
      final meters = distanceMap![w.id];
      if (meters == null) return false;
      return switch (filter.distance!) {
        DistanceFilter.under2k => meters < 2000,
        DistanceFilter.from2to5k => meters >= 2000 && meters < 5000,
        DistanceFilter.from5to10k => meters >= 5000 && meters < 10000,
        DistanceFilter.over10k => meters >= 10000,
      };
    }).toList();
  }

  // Filter by HR zone — match the workout's tag (recovery, aerobic, tempo,
  // threshold, vo2max). Mirrors web's category-card filter; consistent with
  // typing the same word into the search field.
  if (filter.hrZone != null) {
    final tag = kZoneTags[filter.hrZone!];
    filtered = tag == null
        ? const []
        : filtered.where((w) => w.tags.contains(tag)).toList();
  }

  // Filter by collection (tag-set overlap against kCollectionTags).
  if (filter.collectionKey != null) {
    final tags = kCollectionTags[filter.collectionKey!];
    if (tags == null) {
      filtered = const [];
    } else {
      filtered = filtered
          .where((w) => w.tags.any(tags.contains))
          .toList();
    }
  }

  // Filter "My Workouts" — authored by the current user.
  if (filter.mine) {
    final userId = ref.watch(supabaseServiceProvider).currentUserId;
    if (userId == null) {
      filtered = const [];
    } else {
      filtered = filtered.where((w) => w.authorId == userId).toList();
    }
  }

  // Sort — by relevance when searching, otherwise by chosen order.
  final result = List.of(filtered);
  if (searchScores != null) {
    // Primary: relevance score descending. Secondary: current sort order.
    result.sort((a, b) {
      final cmp = searchScores![b.id]!.compareTo(searchScores[a.id]!);
      if (cmp != 0) return cmp;
      return switch (filter.sort) {
        LibrarySortOrder.newest => b.createdAt.compareTo(a.createdAt),
        LibrarySortOrder.duration =>
          durationMap![a.id]!.compareTo(durationMap[b.id]!),
        LibrarySortOrder.mostForked => b.forkCount.compareTo(a.forkCount),
      };
    });
  } else {
    switch (filter.sort) {
      case LibrarySortOrder.newest:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case LibrarySortOrder.duration:
        result.sort(
            (a, b) => durationMap![a.id]!.compareTo(durationMap[b.id]!));
      case LibrarySortOrder.mostForked:
        result.sort((a, b) => b.forkCount.compareTo(a.forkCount));
    }
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
