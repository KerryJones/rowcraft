import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/theme.dart';

/// Reusable Save Workout + Discard button pair.
/// Used inline in scroll views (FTP result) and in sticky bottom bars (summary).
class SaveDiscardButtons extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const SaveDiscardButtons({
    super.key,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save, size: 24),
            label: Text(
              'Save Workout',
              style:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
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
            onPressed: onDiscard,
            icon: const Icon(Icons.delete_outline, size: 24),
            label: Text(
              'Discard',
              style:
                  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
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
    );
  }
}
