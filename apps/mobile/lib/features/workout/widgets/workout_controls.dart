// Start/pause/resume/stop controls shared by both screens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/theme.dart';
import '../../ble/ble_provider.dart';
import '../../ble/pm5_service.dart';
import '../workout_engine.dart';

// ---------------------------------------------------------------------------
// Workout Controls (80px)
// ---------------------------------------------------------------------------

class WorkoutControls extends ConsumerWidget {
  final WorkoutPhase phase;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const WorkoutControls({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm5Connected = ref.watch(bleProvider).pm5ConnectionState ==
        PM5ConnectionState.connected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status hint
          if (phase == WorkoutPhase.idle || phase == WorkoutPhase.ready)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                pm5Connected
                    ? 'Start rowing to begin'
                    : 'Connect rower to start',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: pm5Connected
                          ? RowCraftTheme.warningAmber
                          : RowCraftTheme.subtleGrey,
                    ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: switch (phase) {
              WorkoutPhase.idle || WorkoutPhase.ready => [
                  _ControlButton(
                    icon: Icons.play_arrow,
                    label: 'START',
                    color: pm5Connected
                        ? RowCraftTheme.successGreen
                        : RowCraftTheme.subtleGrey,
                    onPressed: pm5Connected ? onStart : null,
                    isLarge: true,
                  ),
                ],
              WorkoutPhase.countingDown => [
                  const _ControlButton(
                    icon: Icons.hourglass_top,
                    label: 'STARTING...',
                    color: RowCraftTheme.warningAmber,
                    onPressed: null,
                    isLarge: true,
                  ),
                ],
              WorkoutPhase.paused => [
                  _ControlButton(
                    icon: Icons.stop,
                    label: 'STOP',
                    color: RowCraftTheme.errorRose,
                    onPressed: onStop,
                    isLarge: false,
                  ),
                  const SizedBox(width: 32),
                  _ControlButton(
                    icon: Icons.play_arrow,
                    label: 'RESUME',
                    color: RowCraftTheme.successGreen,
                    onPressed: onResume,
                    isLarge: true,
                  ),
                ],
              WorkoutPhase.rowing || WorkoutPhase.resting => [
                  _ControlButton(
                    icon: Icons.pause,
                    label: 'PAUSE',
                    color: RowCraftTheme.warningAmber,
                    onPressed: onPause,
                    isLarge: true,
                  ),
                ],
              WorkoutPhase.structuredComplete ||
              WorkoutPhase.finished => [
                  _ControlButton(
                    icon: Icons.home,
                    label: 'HOME',
                    color: RowCraftTheme.subtleGrey,
                    onPressed: () => context.go('/'),
                    isLarge: true,
                  ),
                ],
            },
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLarge;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.isLarge,
  });

  @override
  Widget build(BuildContext context) {
    final tablet = isTablet(context);
    final size = isLarge
        ? (tablet ? 72.0 : 64.0)
        : (tablet ? 56.0 : 48.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Icon(icon, size: isLarge ? 32 : 24),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}
