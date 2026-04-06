import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../ble/ble_provider.dart';
import '../ble/pm5_service.dart';

/// The Just Row workout UUID from seed data.
const _justRowWorkoutId = 'a0000000-0000-0000-0000-000000000007';

class QuickStartScreen extends ConsumerWidget {
  const QuickStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final pm5Connected =
        bleState.pm5ConnectionState == PM5ConnectionState.connected;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rowing,
                  size: 80,
                  color: pm5Connected
                      ? RowCraftTheme.successGreen
                      : RowCraftTheme.subtleGrey,
                ),
                const SizedBox(height: 24),
                Text(
                  'Just Row',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: RowCraftTheme.metricWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No targets. No time pressure.\nRow at your own pace and sync when done.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: RowCraftTheme.subtleGrey,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: pm5Connected
                        ? () => context.push('/workout/$_justRowWorkoutId/active')
                        : () => context.push('/workout/$_justRowWorkoutId'),
                    style: FilledButton.styleFrom(
                      backgroundColor: pm5Connected
                          ? RowCraftTheme.successGreen
                          : RowCraftTheme.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      pm5Connected ? 'Start Rowing' : 'Connect & Row',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (!pm5Connected) ...[
                  const SizedBox(height: 12),
                  Text(
                    'No rower connected',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: RowCraftTheme.subtleGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
