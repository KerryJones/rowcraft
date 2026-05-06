import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Persistent thin banner shown in debug builds only. Reminds testers
/// that the install was signed with the debug keystore — Android refuses
/// to update across the boundary into a Play Store (release-signed) build.
class DebugBuildBanner extends StatelessWidget {
  final Widget child;
  const DebugBuildBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return Column(
      children: [
        Expanded(child: child),
        SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            color: RowCraftTheme.errorRose.withValues(alpha: 0.9),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: const Text(
              'DEBUG BUILD — uninstall before Play Store update',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
