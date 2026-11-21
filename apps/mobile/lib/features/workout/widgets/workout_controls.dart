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
// Workout Controls (80px bar, or a side rail on landscape phones)
// ---------------------------------------------------------------------------

class WorkoutControls extends ConsumerWidget {
  final WorkoutPhase phase;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  /// Lay out as a narrow right-edge rail instead of a bottom bar. Landscape
  /// phones are short on height and long on width, so a full-width bar
  /// holding one button wastes a quarter of the screen.
  final bool vertical;

  const WorkoutControls({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm5Connected = ref.watch(bleProvider).pm5ConnectionState ==
        PM5ConnectionState.connected;

    final buttons = switch (phase) {
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
          SizedBox(width: vertical ? 0 : 32, height: vertical ? 24 : 0),
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
    };

    // Status hint
    final hint = phase == WorkoutPhase.idle || phase == WorkoutPhase.ready
        ? Text(
            pm5Connected ? 'Start rowing to begin' : 'Connect rower to start',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: pm5Connected
                      ? RowCraftTheme.warningAmber
                      : RowCraftTheme.subtleGrey,
                ),
          )
        : null;

    if (vertical) {
      return Container(
        width: 96,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: const BoxDecoration(
          color: RowCraftTheme.surfaceContainer,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hint != null)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: hint),
            ...buttons,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hint != null)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: hint),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: buttons,
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
    // A landscape phone is wider than 600dp, so isTablet alone would hand it
    // the tablet-size buttons it has no height for.
    final tablet = isTablet(context) && !isLandscapePhone(context);
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
