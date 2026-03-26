import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../services/supabase_service.dart';
import '../../services/c2_logbook_service.dart';
import '../auth/auth_provider.dart';

/// Provider for the user's profile data.
final profileProvider = FutureProvider<Profile>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getProfile();
});

/// Provider for C2 Logbook link status.
final c2LinkedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(c2LogbookServiceProvider);
  return service.isLinked();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final c2LinkedAsync = ref.watch(c2LinkedProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: RowCraftTheme.primaryBlue,
                    child: profileAsync.when(
                      data: (profile) =>
                          _buildInitials(profile.displayName),
                      loading: () => const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                      error: (_, __) => const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display name
                  profileAsync.when(
                    data: (profile) => Text(
                      profile.displayName ?? 'Rower',
                      style: theme.textTheme.headlineMedium,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    currentUser?.email ?? '',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Concept2 Logbook link
          Card(
            child: c2LinkedAsync.when(
              data: (isLinked) => ListTile(
                leading: Icon(
                  Icons.link,
                  color: isLinked
                      ? RowCraftTheme.successGreen
                      : RowCraftTheme.subtleGrey,
                ),
                title: const Text('Concept2 Logbook'),
                subtitle: Text(
                  isLinked ? 'Connected' : 'Not connected',
                ),
                trailing: isLinked
                    ? TextButton(
                        onPressed: () async {
                          final service =
                              ref.read(c2LogbookServiceProvider);
                          await service.disconnect();
                          ref.invalidate(c2LinkedProvider);
                        },
                        child: const Text('Disconnect'),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          final service =
                              ref.read(c2LogbookServiceProvider);
                          await service.authenticate();
                        },
                        child: const Text('Link'),
                      ),
              ),
              loading: () => const ListTile(
                leading: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Concept2 Logbook'),
                subtitle: Text('Checking...'),
              ),
              error: (_, __) => const ListTile(
                leading: Icon(Icons.error_outline,
                    color: RowCraftTheme.errorRose),
                title: Text('Concept2 Logbook'),
                subtitle: Text('Error loading status'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Settings section
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Display Name'),
                  onTap: () => _showEditNameDialog(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About RowCraft'),
                  subtitle: const Text('Version 1.0.0'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'RowCraft',
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          'Structured rowing workouts for Concept2',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign out
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(signOutProvider.future);
              if (context.mounted) {
                context.go('/auth');
              }
            },
            icon: const Icon(Icons.logout, color: RowCraftTheme.errorRose),
            label: Text(
              'Sign Out',
              style: TextStyle(color: RowCraftTheme.errorRose),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: RowCraftTheme.errorRose),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(String? name) {
    final initials = (name ?? 'R')
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Text(
      initials.isEmpty ? 'R' : initials,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Display Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter your display name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final service = ref.read(supabaseServiceProvider);
                  final profile = await service.getProfile();
                  await service.updateProfile(
                    profile.copyWith(displayName: name),
                  );
                  ref.invalidate(profileProvider);
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Display name updated')),
                    );
                  }
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
