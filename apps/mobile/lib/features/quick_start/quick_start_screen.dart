import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Just Row workout UUID from seed data. Exported so the shell can launch
/// the same workout directly from the Quick Start nav tap.
const justRowWorkoutId = 'a0000000-0000-0000-0000-000000000007';

/// Deep-link fallback for `/quick-start`. The Quick Start nav tap is
/// intercepted by ShellScreen and never activates this branch in normal
/// flow — this screen only renders if something navigates to the route
/// directly (e.g. an external deep link).
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
        context.push('/workout/$justRowWorkoutId').then((_) {
          _pushed = false;
          if (mounted) {
            StatefulNavigationShell.maybeOf(context)?.goBranch(0);
          }
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
