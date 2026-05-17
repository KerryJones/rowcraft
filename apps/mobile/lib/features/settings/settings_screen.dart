import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'DISPLAY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: RowCraftTheme.subtleGrey,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Card(
              child: SwitchListTile(
                title: const Text('Show rowing animation'),
                subtitle: const Text(
                    'Animated rower figure on the workout screen'),
                value: settings.showRowingAnimation,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .setShowRowingAnimation(v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
