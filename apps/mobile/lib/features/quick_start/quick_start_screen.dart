import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Just Row workout UUID from seed data.
const _justRowWorkoutId = 'a0000000-0000-0000-0000-000000000007';

/// Quick Start tab — immediately navigates to the Just Row pre-workout screen
/// so it uses the same app bar, connection modal, and "BEGIN WORKOUT" flow
/// as all other workouts.
class QuickStartScreen extends StatefulWidget {
  const QuickStartScreen({super.key});

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate after frame so the widget tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.push('/workout/$_justRowWorkoutId');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Blank scaffold shown for one frame while navigating.
    return const Scaffold();
  }
}
