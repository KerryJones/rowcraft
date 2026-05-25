import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/achievements/achievements_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/ble/connection_gate_screen.dart';
import '../features/library/library_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/quick_start/quick_start_screen.dart';
import '../features/plans/plan_detail_screen.dart';
import '../features/plans/plans_catalog.dart';
import '../features/workout/pre_workout_screen.dart';
import '../features/workout/workout_screen.dart';

import '../features/history/history_screen.dart';
import '../features/history/history_provider.dart';
import '../features/profile/profile_screen.dart';
import '../features/statistics/statistics_screen.dart';
import '../features/settings/pending_sync_screen.dart';
import '../features/settings/settings_screen.dart';
import '../models/workout_result.dart';
import '../services/c2_logbook_service.dart';
import '../utils/time_in_zone.dart';
import '../widgets/hr_zone_donut.dart';
import '../widgets/metric_tile.dart';
import '../app/theme.dart';
import 'shell_screen.dart';

/// Cached onboarding status — set to true after first successful check or
/// after completing onboarding. Avoids repeated DB queries on every route.
bool _onboardingCompleted = false;

/// Mark onboarding as completed in the router cache.
void markOnboardingCompleted() {
  _onboardingCompleted = true;
}

/// Reset onboarding cache (call on sign-out so a different account triggers the check).
void resetOnboardingCache() {
  _onboardingCompleted = false;
}

/// Notifier that triggers go_router refresh on auth state changes.
/// This ensures the redirect fires when the user returns from
/// OAuth (Google sign-in) or when the session expires.
class _AuthNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;

  _AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier();
  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/connect',
    refreshListenable: authNotifier,
    redirect: (BuildContext context, GoRouterState state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;

      // C2 OAuth callback deep link — stay on profile tab.
      // Custom-scheme URIs parse host='login-callback' with empty path.
      final isLoginCallback = state.uri.path == '/login-callback' ||
          state.uri.host == 'login-callback';
      if (isLoginCallback) {
        return isLoggedIn ? '/profile' : '/auth';
      }

      final isAuthRoute = state.matchedLocation == '/auth';
      final isOnboardingRoute = state.matchedLocation == '/onboarding';

      if (!isLoggedIn && !isAuthRoute) {
        return '/auth';
      }
      if (!isLoggedIn) return null;

      // User is logged in — check onboarding status
      if (!_onboardingCompleted && !isOnboardingRoute) {
        try {
          final client = Supabase.instance.client;
          final data = await client
              .from('profiles')
              .select('onboarding_completed')
              .eq('id', client.auth.currentUser!.id)
              .single();
          _onboardingCompleted =
              (data['onboarding_completed'] as bool?) ?? false;
        } catch (_) {
          // On transient error, don't cache — allow retry on next navigation
          return null;
        }
        if (!_onboardingCompleted) return '/onboarding';
      }

      // Redirect from auth route to connect (onboarding already passed)
      if (isAuthRoute) return '/connect';

      // Prevent returning to onboarding once completed
      if (isOnboardingRoute && _onboardingCompleted) return '/connect';

      return null;
    },
    routes: [
      // Auth — outside shell, no bottom nav
      GoRoute(
        path: '/auth',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AuthScreen(),
      ),

      // Onboarding — shown once after first auth
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Connection gate — first screen after auth/onboarding
      GoRoute(
        path: '/connect',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ConnectionGateScreen(),
      ),

      // Workout execution — full-screen, no bottom nav
      GoRoute(
        path: '/workout/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final planId = state.uri.queryParameters['plan'];
          final week = int.tryParse(
              state.uri.queryParameters['week'] ?? '');
          final session = int.tryParse(
              state.uri.queryParameters['session'] ?? '');
          return PreWorkoutScreen(
            workoutId: id,
            planId: planId,
            planWeek: week,
            planSession: session,
          );
        },
      ),
      GoRoute(
        path: '/workout/:id/active',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final planId = state.uri.queryParameters['plan'];
          final week = int.tryParse(
              state.uri.queryParameters['week'] ?? '');
          final session = int.tryParse(
              state.uri.queryParameters['session'] ?? '');
          return WorkoutScreen(
            workoutId: id,
            planId: planId,
            planWeek: week,
            planSession: session,
          );
        },
      ),

      // History — full-screen, accessible from Profile
      GoRoute(
        path: '/history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HistoryScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return HistoryDetailScreen(resultId: id);
            },
          ),
        ],
      ),

      GoRoute(
        path: '/statistics',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StatisticsScreen(),
      ),

      // Devices — full-screen, accessible from Profile and AppBar
      GoRoute(
        path: '/devices',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            const ConnectionGateScreen(isManagement: true),
      ),

      // Achievements — full-screen, accessible from Profile
      GoRoute(
        path: '/achievements',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AchievementsScreen(),
      ),

      // Pending Sync — full-screen, accessible from Profile and home banner
      GoRoute(
        path: '/pending-sync',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PendingSyncScreen(),
      ),

      // Settings — full-screen, accessible from Profile
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),

      // Bottom nav shell with 4 tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          // Tab 0: Workouts (home — post-workout navigation lands here)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const LibraryScreen(),
            ),
          ]),

          // Tab 1: Plans
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/plans',
              builder: (context, state) => const PlansCatalog(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return PlanDetailScreen(planId: id);
                  },
                ),
              ],
            ),
          ]),

          // Tab 2: Quick Start
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/quick-start',
              builder: (context, state) => const QuickStartScreen(),
            ),
          ]),

          // Tab 3: Profile
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

/// Full workout result detail screen.
class HistoryDetailScreen extends ConsumerWidget {
  final String resultId;

  const HistoryDetailScreen({super.key, required this.resultId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(workoutResultProvider(resultId));

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Detail')),
      body: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading result: $e',
              style: const TextStyle(color: RowCraftTheme.errorRose)),
        ),
        data: (result) => result != null
            ? _ResultDetailContent(result: result)
            : const Center(child: Text('Result not found')),
      ),
    );
  }
}

class _ResultDetailContent extends ConsumerStatefulWidget {
  final WorkoutResult result;

  const _ResultDetailContent({required this.result});

  @override
  ConsumerState<_ResultDetailContent> createState() =>
      _ResultDetailContentState();
}

class _ResultDetailContentState extends ConsumerState<_ResultDetailContent> {
  bool _syncing = false;
  late bool _syncedToC2;

  @override
  void initState() {
    super.initState();
    _syncedToC2 = widget.result.syncedToC2;
  }

  Future<void> _syncToC2() async {
    setState(() => _syncing = true);
    try {
      final service = ref.read(c2LogbookServiceProvider);
      final outcome = await service.syncResult(widget.result);
      if (!mounted) return;
      if (outcome.success) {
        setState(() => _syncedToC2 = true);
        ref.invalidate(workoutHistoryProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synced to Concept2 Logbook')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(outcome.error ?? 'Sync failed')),
        );
      }
    } on C2ActionableException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final theme = Theme.of(context);
    final c2LinkedAsync = ref.watch(c2LinkedProvider);
    final profile = ref.watch(profileProvider).value;
    final maxHr = profile?.maxHeartRate ?? 190;
    final restingHr = profile?.restingHeartRate;
    final summaryTiz = timeInZone(result.timeSamples, restingHr, maxHr);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.displayName,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(result.startedAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (summaryTiz.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      HrZoneDonut(
                        timeInZone: summaryTiz,
                        size: 48,
                        strokeWidth: 6,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // Metrics grid
                Row(
                  children: [
                    MetricTile(
                      label: 'Distance',
                      value: '${result.totalDistance.toInt()}m',
                      icon: Icons.straighten,
                    ),
                    MetricTile(
                      label: 'Time',
                      value: result.totalTimeFormatted,
                      icon: Icons.schedule,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    MetricTile(
                      label: 'Avg Split',
                      value: '${result.avgSplitFormatted}/500m',
                      icon: Icons.speed,
                    ),
                    MetricTile(
                      label: 'Avg S/M',
                      value: '${result.avgStrokeRate}',
                      icon: Icons.sync,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    MetricTile(
                      label: 'Avg Watts',
                      value: '${result.avgWatts}',
                      icon: Icons.bolt,
                    ),
                    MetricTile(
                      label: 'Calories',
                      value: '${result.calories}',
                      icon: Icons.local_fire_department,
                    ),
                  ],
                ),
                if (result.avgHeartRate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      MetricTile(
                        label: 'Avg HR',
                        value: '${result.avgHeartRate} bpm',
                        icon: Icons.favorite,
                      ),
                      MetricTile(
                        label: 'C2 Synced',
                        value: _syncedToC2 ? 'Yes' : 'No',
                        icon: Icons.cloud_done,
                      ),
                    ],
                  ),
                ],
                // Retroactive C2 sync: show when not synced and user is linked
                if (!_syncedToC2)
                  c2LinkedAsync.maybeWhen(
                    data: (isLinked) => isLinked
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: _syncing
                                  ? const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: _syncToC2,
                                      icon: const Icon(Icons.sync, size: 18),
                                      label:
                                          const Text('Sync to Concept2'),
                                    ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Splits table
        if (result.splits.isNotEmpty) ...[
          Text('Splits', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(64),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                  4: FlexColumnWidth(),
                },
                children: [
                  const TableRow(
                    children: [
                      _TableHeader('#'),
                      _TableHeader('Dist'),
                      _TableHeader('Pace'),
                      _TableHeader('S/M'),
                      _TableHeader('HR'),
                    ],
                  ),
                  for (final (i, split) in result.splits.indexed)
                    TableRow(
                      children: [
                        _IndexCell(
                          index: i + 1,
                          isRest: split.isRest,
                        ),
                        _TableCell('${split.distance.toInt()}m',
                            isRest: split.isRest),
                        _TableCell(split.paceFormatted, isRest: split.isRest),
                        _TableCell('${split.avgStrokeRate}',
                            isRest: split.isRest),
                        _TableCell(
                          (split.avgHeartRate ?? 0) > 0
                              ? '${split.avgHeartRate}'
                              : '--',
                          isRest: split.isRest,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: RowCraftTheme.subtleGrey,
            ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isRest;
  const _TableCell(this.text, {this.isRest = false});

  @override
  Widget build(BuildContext context) {
    const baseColor = RowCraftTheme.metricWhite;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isRest ? baseColor.withValues(alpha: 0.6) : baseColor,
            ),
      ),
    );
  }
}

class _IndexCell extends StatelessWidget {
  final int index;
  final bool isRest;

  const _IndexCell({
    required this.index,
    required this.isRest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indexColor = isRest
        ? RowCraftTheme.subtleGrey.withValues(alpha: 0.6)
        : RowCraftTheme.subtleGrey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            '$index',
            style: theme.textTheme.bodySmall?.copyWith(color: indexColor),
          ),
          if (isRest) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Rest',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: RowCraftTheme.segmentRest,
                  fontWeight: FontWeight.w600,
                ),
                softWrap: false,
                overflow: TextOverflow.clip,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

