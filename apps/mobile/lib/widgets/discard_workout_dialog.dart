import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';
import '../features/workout/workout_provider.dart';

/// Shows a confirmation dialog for discarding a workout result.
/// On confirm, calls [discardResult] and navigates home.
void showDiscardWorkoutDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: RowCraftTheme.surfaceContainer,
      title: Text(
        'Discard workout?',
        style: GoogleFonts.inter(
          color: RowCraftTheme.metricWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        'This workout result will be permanently deleted.',
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
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.arrow_back, size: 24),
                label: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RowCraftTheme.primaryBlue,
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
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(workoutSessionProvider.notifier).discardResult();
                  if (context.mounted) context.go('/');
                },
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
    ),
  );
}
