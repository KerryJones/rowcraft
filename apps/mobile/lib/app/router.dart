import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_screen.dart';
import '../features/ble/connect_screen.dart';
import '../features/ble/connection_gate_screen.dart';
import '../features/library/library_screen.dart';
import '../features/plans/plan_detail_screen.dart';
import '../features/plans/plans_catalog.dart';
import '../features/workout/pre_workout_screen.dart';
import '../features/workout/workout_screen.dart';

import '../features/history/history_screen.dart';
import '../features/history/history_provider.dart';
import '../features/profile/profile_screen.dart';
import '../models/workout_result.dart';
import '../app/theme.dart';
import 'shell_screen.dart';

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
    redirect: (BuildContext context, GoRouterState state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isAuthRoute = state.matchedLocation == '/auth';

      if (!isLoggedIn && !isAuthRoute) {
        return '/auth';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/connect';
      }
      return null;
    },
    routes: [
      // Auth — outside shell, no bottom nav
      GoRoute(
        path: '/auth',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AuthScreen(),
      ),

      // Connection gate — first screen after auth
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

      // Bottom nav shell with 5 tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          // Tab 0: Workouts
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

          // Tab 2: History
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/history',
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
          ]),

          // Tab 3: Devices
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/devices',
              builder: (context, state) => const ConnectScreen(),
            ),
          ]),

          // Tab 4: Profile
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

class _ResultDetailContent extends StatelessWidget {
  final WorkoutResult result;

  const _ResultDetailContent({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                Text(
                  result.workoutId != null ? 'Structured Workout' : 'Free Row',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(result.startedAt),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                // Metrics grid
                Row(
                  children: [
                    _MetricTile(
                      label: 'Distance',
                      value: '${result.totalDistance.toInt()}m',
                    ),
                    _MetricTile(
                      label: 'Time',
                      value: result.totalTimeFormatted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetricTile(
                      label: 'Avg Split',
                      value: '${result.avgSplitFormatted}/500m',
                    ),
                    _MetricTile(
                      label: 'Avg SPM',
                      value: '${result.avgStrokeRate}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetricTile(
                      label: 'Avg Watts',
                      value: '${result.avgWatts}',
                    ),
                    _MetricTile(
                      label: 'Calories',
                      value: '${result.calories}',
                    ),
                  ],
                ),
                if (result.avgHeartRate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MetricTile(
                        label: 'Avg HR',
                        value: '${result.avgHeartRate} bpm',
                      ),
                      _MetricTile(
                        label: 'C2 Synced',
                        value: result.syncedToC2 ? 'Yes' : 'No',
                      ),
                    ],
                  ),
                ],
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
                  0: FixedColumnWidth(32),
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
                      _TableHeader('SPM'),
                      _TableHeader('Watts'),
                    ],
                  ),
                  for (var i = 0; i < result.splits.length; i++)
                    TableRow(
                      children: [
                        _TableCell('${i + 1}', isIndex: true),
                        _TableCell('${result.splits[i].distance.toInt()}m'),
                        _TableCell(result.splits[i].paceFormatted),
                        _TableCell('${result.splits[i].avgStrokeRate}'),
                        _TableCell('${result.splits[i].avgWatts}'),
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

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: RowCraftTheme.subtleGrey,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: RowCraftTheme.metricWhite,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
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
  final bool isIndex;
  const _TableCell(this.text, {this.isIndex = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isIndex ? RowCraftTheme.subtleGrey : RowCraftTheme.metricWhite,
            ),
      ),
    );
  }
}
