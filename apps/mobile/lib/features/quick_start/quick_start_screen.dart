import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Just Row workout UUID from seed data.
const _justRowWorkoutId = 'a0000000-0000-0000-0000-000000000007';

/// Quick Start tab — immediately navigates to the Just Row pre-workout screen
/// so it uses the same app bar, connection modal, and "BEGIN WORKOUT" flow
/// as all other workouts. Re-navigates whenever the user returns to this tab.
class QuickStartScreen extends StatefulWidget {
  const QuickStartScreen({super.key});

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  bool _pushed = false;

  @override
  void initState() {
    super.initState();
    _navigateToWorkout();
  }

  void _navigateToWorkout() {
    if (_pushed) return;
    _pushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.push('/workout/$_justRowWorkoutId').then((_) {
          _pushed = false;
          if (mounted) _navigateToWorkout();
        });
      } else {
        _pushed = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}
