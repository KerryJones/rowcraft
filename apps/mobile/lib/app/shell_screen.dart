import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/quick_start/quick_start_screen.dart' show justRowWorkoutId;
import 'adaptive.dart';
import 'shell_app_bar_actions_provider.dart';

const _destinations = [
  (
    icon: Icons.fitness_center_outlined,
    selected: Icons.fitness_center,
    label: 'Workouts',
  ),
  (
    icon: Icons.calendar_month_outlined,
    selected: Icons.calendar_month,
    label: 'Plans',
  ),
  (
    icon: Icons.play_circle_outline,
    selected: Icons.play_circle,
    label: 'Quick Start',
  ),
  (icon: Icons.person_outline, selected: Icons.person, label: 'Profile'),
];

class ShellScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  late int _previousIndex = widget.navigationShell.currentIndex;

  void _launchJustRow() {
    context.push('/workout/$justRowWorkoutId').then((_) {
      if (!mounted) return;
      widget.navigationShell.goBranch(0);
      // Sync _previousIndex so the next tab tap still clears AppBar actions.
      ref.read(shellAppBarActionsProvider.notifier).state = [];
      _previousIndex = 0;
    });
  }

  void _onDestinationSelected(int index) {
    if (index == 2) {
      _launchJustRow();
      return;
    }
    if (index != _previousIndex) {
      ref.read(shellAppBarActionsProvider.notifier).state = [];
      _previousIndex = index;
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = isTablet(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _launchJustRow();
        }
      },
      child: Scaffold(
        body: tablet
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: widget.navigationShell.currentIndex,
                    onDestinationSelected: _onDestinationSelected,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selected),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: widget.navigationShell),
                ],
              )
            : widget.navigationShell,
        bottomNavigationBar: tablet
            ? null
            : NavigationBar(
                selectedIndex: widget.navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: d.label,
                    ),
                ],
              ),
      ),
    );
  }
}
