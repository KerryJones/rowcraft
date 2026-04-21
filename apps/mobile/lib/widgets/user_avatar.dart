import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../features/profile/profile_screen.dart' show profileProvider;

/// Reusable avatar widget showing user initials in a circle.
class UserAvatar extends ConsumerWidget {
  static final _whitespace = RegExp(r'\s+');

  final double radius;

  const UserAvatar({super.key, this.radius = 16});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return CircleAvatar(
      radius: radius,
      backgroundColor: RowCraftTheme.primaryBlue,
      child: profileAsync.when(
        data: (profile) => Text(
          _initials(profile.displayName),
          style: TextStyle(
            fontSize: radius * 0.75,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        loading: () => SizedBox(
          width: radius * 0.7,
          height: radius * 0.7,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
        error: (_, _) => Icon(Icons.person, size: radius),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(_whitespace);
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }
}
