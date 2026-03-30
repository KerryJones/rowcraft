import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../services/supabase_service.dart';
import '../../services/c2_logbook_service.dart';
import '../../utils/pace_utils.dart';
import '../auth/auth_provider.dart';

/// Provider for the user's profile data.
final profileProvider = FutureProvider<Profile>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getProfile();
});

/// Provider for FTP history.
final ftpHistoryProvider = FutureProvider<List<FtpRecord>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getFtpHistory();
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

          // FTP card
          _FtpCard(),
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
            label: const Text(
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

  static void _showManualFtpDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ManualFtpDialog(ref: ref),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EditNameDialog(ref: ref),
    );
  }
}

class _FtpCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final ftpHistoryAsync = ref.watch(ftpHistoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('FTP', style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () {
                    ProfileScreen._showManualFtpDialog(context, ref);
                  },
                  child: const Text('Set Manually'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Current FTP as pace
            profileAsync.when(
              data: (profile) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.currentFtpWatts != null
                        ? wattsToPaceString(profile.currentFtpWatts!)
                        : 'Not tested',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: profile.currentFtpWatts != null
                          ? RowCraftTheme.successGreen
                          : RowCraftTheme.subtleGrey,
                    ),
                  ),
                  if (profile.currentFtpWatts != null)
                    Text(
                      '${profile.currentFtpWatts}W',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: RowCraftTheme.subtleGrey,
                      ),
                    ),
                ],
              ),
              loading: () => const SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => Text(
                'Error',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: RowCraftTheme.errorRose,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // FTP history
            ftpHistoryAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return Text(
                    'Complete an FTP test to see history',
                    style: theme.textTheme.bodySmall,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('History', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    ...records.take(5).map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text(
                                wattsToPaceString(r.ftpWatts),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${r.ftpWatts}W',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: RowCraftTheme.subtleGrey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                r.testType,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: RowCraftTheme.subtleGrey,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(r.testedAt),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        )),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

/// Stateful dialog for manual FTP entry — properly disposes its controller.
class _ManualFtpDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ManualFtpDialog({required this.ref});

  @override
  State<_ManualFtpDialog> createState() => _ManualFtpDialogState();
}

class _ManualFtpDialogState extends State<_ManualFtpDialog> {
  final _controller = TextEditingController();
  String _pacePreview = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updatePacePreview);
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePacePreview);
    _controller.dispose();
    super.dispose();
  }

  void _updatePacePreview() {
    final watts = int.tryParse(_controller.text.trim());
    setState(() {
      _pacePreview = watts != null && watts > 0
          ? wattsToPaceString(watts)
          : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set FTP Manually'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter FTP in watts',
              suffixText: 'W',
            ),
            autofocus: true,
          ),
          if (_pacePreview.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _pacePreview,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RowCraftTheme.successGreen,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final watts = int.tryParse(_controller.text.trim());
            if (watts != null && watts > 0) {
              final service = widget.ref.read(supabaseServiceProvider);
              final userId = service.currentUserId;
              if (userId != null) {
                await service.saveFtpRecord(FtpRecord(
                  id: '',
                  userId: userId,
                  testedAt: DateTime.now(),
                  ftpWatts: watts,
                  testType: 'manual',
                ));
                await service.updateProfileFtp(watts);
                widget.ref.invalidate(profileProvider);
                widget.ref.invalidate(ftpHistoryProvider);
              }
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Stateful dialog for editing display name — properly disposes its controller.
class _EditNameDialog extends StatefulWidget {
  final WidgetRef ref;
  const _EditNameDialog({required this.ref});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Display Name'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Enter your display name',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              final service = widget.ref.read(supabaseServiceProvider);
              final profile = await service.getProfile();
              await service.updateProfile(
                profile.copyWith(displayName: name),
              );
              widget.ref.invalidate(profileProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Display name updated')),
                );
              }
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
