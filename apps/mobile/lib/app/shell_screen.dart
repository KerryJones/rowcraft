import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adaptive.dart';

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

class ShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellScreen({super.key, required this.navigationShell});

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = isTablet(context);

    return PopScope(
      canPop: navigationShell.currentIndex == 2,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          navigationShell.goBranch(2, initialLocation: true);
        }
      },
      child: Scaffold(
        body: tablet
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: navigationShell.currentIndex,
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
                  Expanded(child: navigationShell),
                ],
              )
            : navigationShell,
        bottomNavigationBar: tablet
            ? null
            : NavigationBar(
                selectedIndex: navigationShell.currentIndex,
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
