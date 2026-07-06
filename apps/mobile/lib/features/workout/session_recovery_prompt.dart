import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../models/workout_result.dart';
import '../../services/session_recovery_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../utils/app_log.dart';
import '../history/history_provider.dart';

/// Check for an orphaned in-progress session snapshot (app was killed or
/// crashed mid-workout) and offer to save or discard it.
///
/// Called once on app startup from the shell screen.
Future<void> maybePromptSessionRecovery(
  BuildContext context,
  WidgetRef ref,
) async {
  final recovery = ref.read(sessionRecoveryServiceProvider);
  final result = await recovery.loadSnapshot();
  if (result == null) return;

  // A snapshot from a different account can't be saved under this user —
  // drop it rather than prompting forever.
  final currentUserId = ref.read(supabaseServiceProvider).currentUserId;
  if (currentUserId == null || currentUserId != result.userId) {
    await recovery.clear();
    return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => _SessionRecoveryDialog(result: result),
  );
}

class _SessionRecoveryDialog extends ConsumerStatefulWidget {
  final WorkoutResult result;

  const _SessionRecoveryDialog({required this.result});

  @override
  ConsumerState<_SessionRecoveryDialog> createState() =>
      _SessionRecoveryDialogState();
}

class _SessionRecoveryDialogState
    extends ConsumerState<_SessionRecoveryDialog> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(syncServiceProvider).queueResult(widget.result);
      await ref.read(sessionRecoveryServiceProvider).clear();
      ref.invalidate(workoutHistoryProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovered workout saved to history')),
      );
    } catch (e, st) {
      AppLog.error('workout', 'Recovered session save failed', e, st);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saving failed: $e')),
      );
    }
  }

  Future<void> _discard() async {
    await ref.read(sessionRecoveryServiceProvider).clear();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final meters = result.totalDistance.round();
    return AlertDialog(
      backgroundColor: RowCraftTheme.surfaceContainer,
      title: Text(
        'Recover Workout?',
        style: GoogleFonts.inter(
          color: RowCraftTheme.metricWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        '${result.displayName} (${meters}m, ${result.totalTimeFormatted}) '
        'was interrupted before it could be saved.',
        style: GoogleFonts.inter(color: RowCraftTheme.subtleGrey),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save, size: 24),
                label: Text(
                  _saving ? 'Saving…' : 'Save Workout',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RowCraftTheme.successGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _discard,
                icon: const Icon(Icons.delete_outline, size: 24),
                label: Text(
                  'Discard',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: RowCraftTheme.errorRose,
                  side: const BorderSide(
                      color: RowCraftTheme.errorRose, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
