import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/workout.dart';
import '../../services/supabase_service.dart';
import '../../services/workout_repository.dart';
import '../../utils/pace_utils.dart' show kDefaultFtpWatts;
import '../../utils/workout_utils.dart';
import '../../widgets/ble_status_button.dart';
import '../../widgets/wod_card.dart';
import '../../widgets/workout_graph.dart';
import '../plans/plans_provider.dart';
import '../profile/profile_screen.dart' show profileProvider;
import 'library_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  DurationFilter? _duration;
  DistanceFilter? _distance;
  int? _zone;
  String? _collectionKey;
  bool _mine = false;
  LibrarySortOrder _sortOrder = LibrarySortOrder.newest;
  int _wodShuffleOffset = 0;

  bool get _hasAnyFilter =>
      _duration != null ||
      _distance != null ||
      _zone != null ||
      _collectionKey != null ||
      _mine;

  bool get _isBrowsing =>
      _hasAnyFilter || _searchController.text.isNotEmpty;

  void _clearAll() {
    setState(() {
      _duration = null;
      _distance = null;
      _zone = null;
      _collectionKey = null;
      _mine = false;
      _searchController.clear();
    });
  }

  /// Mutually-exclusive tile select: resets all other filters, then toggles
  /// the tapped one (tap-again deselects). Mirrors the web CategoryCards
  /// `toggle()` behavior.
  void _selectTile(_TileDef tile) {
    setState(() {
      final wasActive = _isTileActive(tile);
      _duration = null;
      _distance = null;
      _zone = null;
      _collectionKey = null;
      _mine = false;
      if (wasActive) return;
      switch (tile.type) {
        case _TileType.duration:
          _duration = tile.duration;
        case _TileType.distance:
          _distance = tile.distance;
        case _TileType.zone:
          _zone = tile.zone;
        case _TileType.collection:
          _collectionKey = tile.collectionKey;
        case _TileType.mine:
          _mine = true;
      }
    });
  }

  bool _isTileActive(_TileDef tile) {
    return switch (tile.type) {
      _TileType.duration => _duration == tile.duration,
      _TileType.distance => _distance == tile.distance,
      _TileType.zone => _zone == tile.zone,
      _TileType.collection => _collectionKey == tile.collectionKey,
      _TileType.mine => _mine,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = ref.watch(supabaseServiceProvider).currentUserId;

    final workoutsAsync = ref.watch(filteredWorkoutsProvider((
      search: _searchController.text,
      type: null,
      tag: null,
      duration: _duration,
      distance: _distance,
      hrZone: _zone,
      collectionKey: _collectionKey,
      mine: _mine,
      sort: _sortOrder,
    )));
    final userFtp = ref.watch(profileProvider).valueOrNull?.currentFtpWatts ?? kDefaultFtpWatts;
    // Watch at top of build so WOD fetch runs in parallel with the library
    // list fetch, instead of only starting after the list resolves.
    final wodAsync = ref.watch(wodWorkoutsProvider);
    final plansAsync = ref.watch(trainingPlansProvider);

    // Resolve the WOD unconditionally — it is pinned at the top of the screen
    // in both the landing (tiles) and browsing (list) states.
    const wodExcludeTags = {'ftp', 'ramp', 'test'};
    final plans = plansAsync.valueOrNull ?? [];
    final planWorkoutIds = <String>{
      for (final plan in plans)
        for (final week in plan.weeks)
          for (final session in week.sessions) session.workoutId,
    };
    Workout? wodWorkout;
    int wodPoolLength = 0;
    if (wodAsync.hasValue) {
      final wodPool = wodAsync.value!
          .where((w) =>
              !w.tags.any(wodExcludeTags.contains) &&
              !planWorkoutIds.contains(w.id))
          .toList();
      wodPoolLength = wodPool.length;
      if (wodPool.isNotEmpty) {
        final wodIdx = getWodIndex(wodPool.length,
            shuffleOffset: _wodShuffleOffset);
        wodWorkout = wodPool[wodIdx];
      }
    }
    final wod = wodWorkout;
    final wodLoading = wodAsync.isLoading && wod == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          if (_isBrowsing)
            _SortButton(
              current: _sortOrder,
              onSelected: (order) => setState(() => _sortOrder = order),
            ),
          const BleStatusButton(),
        ],
      ),
      body: Column(
        children: [
          // WOD slot — pinned at top, but suppressed when browsing "My
          // Workouts" (a public WOD above a private list is confusing).
          if (wod != null && !_mine)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: WodCard(
                workout: wod,
                canShuffle: wodPoolLength > 1,
                ftpWatts: userFtp,
                onTap: () => context.push('/workout/${wod.id}'),
                onShuffle: () {
                  setState(() => _wodShuffleOffset++);
                },
              ),
            )
          else if (wodLoading && !_mine)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _WodLoadingPlaceholder(),
            ),

          // Search bar — always visible.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search workouts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Body: tiles (landing) or filtered list (browsing).
          Expanded(
            child: _isBrowsing
                ? _buildBrowsingList(
                    context,
                    theme,
                    workoutsAsync,
                    _mine ? null : wod,
                    userFtp,
                  )
                : _buildTilesGrid(context, userId),
          ),
        ],
      ),
    );
  }

  // ── Landing: tile grid ────────────────────────────────────────

  Widget _buildTilesGrid(BuildContext context, String? userId) {
    final tiles = _visibleTiles(userId: userId);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return _CategoryTile(
          tile: tile,
          active: _isTileActive(tile),
          onTap: () => _selectTile(tile),
        );
      },
    );
  }

  // ── Browsing: filtered list ───────────────────────────────────

  Widget _buildBrowsingList(
    BuildContext context,
    ThemeData theme,
    AsyncValue<List<Workout>> workoutsAsync,
    Workout? wod,
    int ftpWatts,
  ) {
    return workoutsAsync.when(
      data: (workouts) {
        // Deduplicate: if the pinned WOD would appear in the list, drop it
        // so it doesn't render twice — but only when there's more than one
        // workout, so a filtered list containing just the WOD doesn't
        // render as empty.
        final displayWorkouts = wod != null && workouts.length > 1
            ? workouts.where((w) => w.id != wod.id).toList()
            : workouts;

        Future<void> onRefresh() async {
          final repo = ref.read(workoutRepositoryProvider);
          await repo.refreshWorkouts(isPublic: true);
          ref.read(workoutRefreshTriggerProvider.notifier).state++;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Workouts'),
                    style: TextButton.styleFrom(
                      foregroundColor: RowCraftTheme.subtleGrey,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${displayWorkouts.length} result${displayWorkouts.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: RowCraftTheme.subtleGrey,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: displayWorkouts.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.rowing,
                                    size: 64,
                                    color: RowCraftTheme.subtleGrey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No workouts found',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: RowCraftTheme.subtleGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: displayWorkouts.length,
                        itemBuilder: (context, index) =>
                            _WorkoutCard(workout: displayWorkouts[index], ftpWatts: ftpWatts),
                      ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: RowCraftTheme.errorRose,
            ),
            const SizedBox(height: 16),
            Text('Failed to load workouts', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(workoutLibraryProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  List<_TileDef> _visibleTiles({required String? userId}) {
    return [
      for (final t in _kAllTiles)
        if (!(t.type == _TileType.mine && userId == null)) t,
    ];
  }
}

// ── Tile model & catalogue ──────────────────────────────────────

enum _TileType { duration, distance, zone, collection, mine }

class _TileDef {
  final _TileType type;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color bgStart;
  final Color bgEnd;
  final Color ring;
  final DurationFilter? duration;
  final DistanceFilter? distance;
  final int? zone;
  final String? collectionKey;

  const _TileDef({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.bgStart,
    required this.bgEnd,
    required this.ring,
    this.duration,
    this.distance,
    this.zone,
    this.collectionKey,
  });
}

const _kAllTiles = <_TileDef>[
  // Duration
  _TileDef(
    type: _TileType.duration,
    label: 'Under 30m',
    subtitle: 'Quick hits',
    icon: Icons.schedule,
    bgStart: Color(0xFF0284C7),
    bgEnd: Color(0xFF075985),
    ring: Color(0xFF38BDF8),
    duration: DurationFilter.under30,
  ),
  _TileDef(
    type: _TileType.duration,
    label: '30–60m',
    subtitle: 'Sweet spot',
    icon: Icons.schedule,
    bgStart: Color(0xFF059669),
    bgEnd: Color(0xFF065F46),
    ring: Color(0xFF34D399),
    duration: DurationFilter.from30to60,
  ),
  _TileDef(
    type: _TileType.duration,
    label: '60m+',
    subtitle: 'Long haul',
    icon: Icons.schedule,
    bgStart: Color(0xFFD97706),
    bgEnd: Color(0xFF92400E),
    ring: Color(0xFFFBBF24),
    duration: DurationFilter.over60,
  ),
  // Distance
  _TileDef(
    type: _TileType.distance,
    label: '≤2k',
    subtitle: 'Sprint',
    icon: Icons.straighten,
    bgStart: Color(0xFF0D9488),
    bgEnd: Color(0xFF115E59),
    ring: Color(0xFF2DD4BF),
    distance: DistanceFilter.under2k,
  ),
  _TileDef(
    type: _TileType.distance,
    label: '2–5k',
    subtitle: 'Short',
    icon: Icons.straighten,
    bgStart: Color(0xFF0891B2),
    bgEnd: Color(0xFF155E75),
    ring: Color(0xFF22D3EE),
    distance: DistanceFilter.from2to5k,
  ),
  _TileDef(
    type: _TileType.distance,
    label: '5–10k',
    subtitle: 'Mid',
    icon: Icons.straighten,
    bgStart: Color(0xFF0F766E),
    bgEnd: Color(0xFF064E3B),
    ring: Color(0xFF2DD4BF),
    distance: DistanceFilter.from5to10k,
  ),
  _TileDef(
    type: _TileType.distance,
    label: '10k+',
    subtitle: 'Long',
    icon: Icons.straighten,
    bgStart: Color(0xFF047857),
    bgEnd: Color(0xFF134E4A),
    ring: Color(0xFF34D399),
    distance: DistanceFilter.over10k,
  ),
  // Zones — HR zone colors
  _TileDef(
    type: _TileType.zone,
    label: 'Recovery',
    subtitle: 'Z1',
    icon: Icons.favorite,
    bgStart: Color(0xFF16A34A),
    bgEnd: Color(0xFF14532D),
    ring: Color(0xFF4ADE80),
    zone: 1,
  ),
  _TileDef(
    type: _TileType.zone,
    label: 'Aerobic',
    subtitle: 'Z2',
    icon: Icons.air,
    bgStart: Color(0xFF0EA5E9),
    bgEnd: Color(0xFF1D4ED8),
    ring: Color(0xFF38BDF8),
    zone: 2,
  ),
  _TileDef(
    type: _TileType.zone,
    label: 'Tempo',
    subtitle: 'Z3',
    icon: Icons.show_chart,
    bgStart: Color(0xFFF59E0B),
    bgEnd: Color(0xFFB45309),
    ring: Color(0xFFFBBF24),
    zone: 3,
  ),
  _TileDef(
    type: _TileType.zone,
    label: 'Threshold',
    subtitle: 'Z4',
    icon: Icons.local_fire_department,
    bgStart: Color(0xFFF97316),
    bgEnd: Color(0xFFC2410C),
    ring: Color(0xFFFB923C),
    zone: 4,
  ),
  _TileDef(
    type: _TileType.zone,
    label: 'VO2max',
    subtitle: 'Z5',
    icon: Icons.bolt,
    bgStart: Color(0xFFEF4444),
    bgEnd: Color(0xFFB91C1C),
    ring: Color(0xFFF87171),
    zone: 5,
  ),
  // Collections
  _TileDef(
    type: _TileType.collection,
    label: 'FTP Builder',
    subtitle: 'Build power',
    icon: Icons.trending_up,
    bgStart: Color(0xFFDB2777),
    bgEnd: Color(0xFF831843),
    ring: Color(0xFFF472B6),
    collectionKey: 'ftp-builder',
  ),
  _TileDef(
    type: _TileType.collection,
    label: '2K Race Prep',
    subtitle: 'Peak',
    icon: Icons.flag,
    bgStart: Color(0xFF4F46E5),
    bgEnd: Color(0xFF312E81),
    ring: Color(0xFF818CF8),
    collectionKey: '2k-race-prep',
  ),
  _TileDef(
    type: _TileType.collection,
    label: 'WODs',
    subtitle: 'Challenges',
    icon: Icons.emoji_events,
    bgStart: Color(0xFFEA580C),
    bgEnd: Color(0xFF7C2D12),
    ring: Color(0xFFFB923C),
    collectionKey: 'wods',
  ),
  _TileDef(
    type: _TileType.collection,
    label: 'Classics',
    subtitle: 'Benchmarks',
    icon: Icons.military_tech,
    bgStart: Color(0xFFCA8A04),
    bgEnd: Color(0xFF713F12),
    ring: Color(0xFFFACC15),
    collectionKey: 'classics',
  ),
  // Special
  _TileDef(
    type: _TileType.mine,
    label: 'My Workouts',
    subtitle: 'Personal',
    icon: Icons.person,
    bgStart: Color(0xFF4B5563),
    bgEnd: Color(0xFF1F2937),
    ring: Color(0xFF9CA3AF),
  ),
];

// ── Category tile widget ────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final _TileDef tile;
  final bool active;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.tile,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tile.bgStart, tile.bgEnd],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? tile.ring : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tile.icon, color: Colors.white.withValues(alpha: 0.9), size: 30),
                const SizedBox(height: 8),
                Text(
                  tile.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tile.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sort popup menu button shown in the AppBar.
class _SortButton extends StatelessWidget {
  final LibrarySortOrder current;
  final ValueChanged<LibrarySortOrder> onSelected;

  const _SortButton({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDefault = current == LibrarySortOrder.newest;
    return PopupMenuButton<LibrarySortOrder>(
      icon: Badge(
        isLabelVisible: !isDefault,
        child: const Icon(Icons.sort),
      ),
      tooltip: 'Sort',
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (_) => [
        _sortItem(LibrarySortOrder.newest, 'Newest', current),
        _sortItem(LibrarySortOrder.duration, 'Duration', current),
        _sortItem(LibrarySortOrder.mostForked, 'Most Forked', current),
      ],
    );
  }

  PopupMenuItem<LibrarySortOrder> _sortItem(
    LibrarySortOrder value,
    String label,
    LibrarySortOrder current,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (value == current)
            const Icon(Icons.check, size: 16)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// Workout card with duration as hero element.
class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final int ftpWatts;

  const _WorkoutCard({required this.workout, this.ftpWatts = kDefaultFtpWatts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalDist = computeTotalDistance(workout.segments);
    final totalTime = computeTotalTime(workout.segments);
    final estimatedSecs = computeEstimatedTotalTime(workout.segments, ftpWatts);
    final dominantZone = computeDominantZone(workout.segments);

    // Hero value: distance for distance workouts, time for everything else
    final heroValue = workout.workoutType == WorkoutType.singleDistance
        ? formatDistance(totalDist ?? 0)
        : formatDuration(totalTime ?? estimatedSecs);

    const zoneColors = {
      1: RowCraftTheme.hrZone1,
      2: RowCraftTheme.hrZone2,
      3: RowCraftTheme.hrZone3,
      4: RowCraftTheme.hrZone4,
      5: RowCraftTheme.hrZone5,
    };

    return Card(
      child: InkWell(
        onTap: () => context.push('/workout/${workout.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero row: duration + type badge + zone
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    heroValue,
                    style: theme.textTheme.displaySmall,
                  ),
                  const Spacer(),
                  if (dominantZone != null && zoneColors.containsKey(dominantZone)) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: zoneColors[dominantZone]!.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Z$dominantZone',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: zoneColors[dominantZone],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Segment graph
              WorkoutGraph(segments: workout.segments, height: 48),

              const SizedBox(height: 10),

              // Title
              Text(
                workout.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              // Metadata + tags
              Row(
                children: [
                  // Tags
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: workout.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: RowCraftTheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: RowCraftTheme.subtleGrey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Metadata
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.segment,
                          size: 12, color: RowCraftTheme.subtleGrey),
                      const SizedBox(width: 3),
                      Text(
                        '${workout.segments.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: RowCraftTheme.subtleGrey,
                        ),
                      ),
                      if (workout.forkCount > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.fork_right,
                            size: 12, color: RowCraftTheme.subtleGrey),
                        const SizedBox(width: 3),
                        Text(
                          '${workout.forkCount}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: RowCraftTheme.subtleGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder shown while the WOD is loading. Matches the approximate
/// height of [WodCard] so the list doesn't shift when the WOD resolves.
class _WodLoadingPlaceholder extends StatelessWidget {
  const _WodLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading workout of the day',
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: RowCraftTheme.warningAmber.withValues(alpha: 0.3),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              RowCraftTheme.warningAmber.withValues(alpha: 0.1),
              RowCraftTheme.surfaceContainer,
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: RowCraftTheme.warningAmber,
          ),
        ),
      ),
    );
  }
}
