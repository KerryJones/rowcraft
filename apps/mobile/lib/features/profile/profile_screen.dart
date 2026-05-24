import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_version_provider.dart';
import '../../app/theme.dart';
import '../../widgets/content_constraint.dart';
import '../../widgets/row_craft_app_bar.dart';
import '../../widgets/user_avatar.dart';
import '../../services/supabase_service.dart';
import '../../services/c2_logbook_service.dart';
import '../../services/plexo_service.dart';
import '../../services/strava_service.dart';
import '../../utils/hr_zones.dart';
import '../../utils/pace_utils.dart';
import '../auth/auth_provider.dart';
import '../ble/ble_provider.dart';
import '../history/history_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ble/pm5_service.dart';

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

/// Provider for Strava link status.
final stravaLinkedProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(stravaServiceProvider);
  return service.isLinked();
});


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static void showManualFtpDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ManualFtpDialog(ref: ref),
    );
  }

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  bool _c2Linking = false;
  bool _waitingForC2Auth = false;
  bool _stravaLinking = false;
  bool _waitingForStravaAuth = false;
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSub?.cancel();
    super.dispose();
  }

  void _listenForDeepLinks() {
    final appLinks = AppLinks();
    _deepLinkSub = appLinks.uriLinkStream.listen((uri) {
      if (!mounted) return;
      if (uri.scheme == 'com.rowcraft.app' && uri.host == 'login-callback') {
        final service = uri.queryParameters['service'];
        _waitingForC2Auth = false;
        _waitingForStravaAuth = false;
        ref.invalidate(c2LinkedProvider);
        ref.invalidate(stravaLinkedProvider);
        final label = service == 'strava' ? 'Strava' : 'Concept2 Logbook';
        if (uri.queryParameters['success'] == 'true') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label connected!')),
          );
        } else {
          final error = uri.queryParameters['error'] ?? 'Connection failed';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label connection failed: $error')),
          );
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh C2 status when returning from the browser OAuth flow,
    // as a fallback in case the deep link doesn't fire. Only fires when
    // we actually sent the user to the browser for C2 auth.
    if (state == AppLifecycleState.resumed) {
      if (_waitingForC2Auth) {
        _waitingForC2Auth = false;
        ref.invalidate(c2LinkedProvider);
      }
      if (_waitingForStravaAuth) {
        _waitingForStravaAuth = false;
        ref.invalidate(stravaLinkedProvider);
      }
    }
  }

  Future<void> _linkC2() async {
    setState(() => _c2Linking = true);
    try {
      final service = ref.read(c2LogbookServiceProvider);
      await service.authenticate();
      // Mark that we launched the browser — resume will refresh C2 status.
      _waitingForC2Auth = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _c2Linking = false);
    }
  }

  Future<void> _linkStrava() async {
    setState(() => _stravaLinking = true);
    try {
      final service = ref.read(stravaServiceProvider);
      await service.authenticate();
      _waitingForStravaAuth = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _stravaLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final c2LinkedAsync = ref.watch(c2LinkedProvider);
    final stravaLinkedAsync = ref.watch(stravaLinkedProvider);
    final currentUser = ref.watch(currentUserProvider);
    final bleState = ref.watch(bleProvider);
    final pm5Connected =
        bleState.pm5ConnectionState == PM5ConnectionState.connected;

    return Scaffold(
      appBar: const RowCraftAppBar(title: 'Profile', showProfileAvatar: false),
      body: ContentConstraint(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const UserAvatar(radius: 40),
                    const SizedBox(height: 16),

                    // Display name
                    profileAsync.when(
                      data: (profile) => Text(
                        profile.displayName ?? 'Rower',
                        style: theme.textTheme.headlineMedium,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
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

            // Navigation items (History, Devices)
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Workout History'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/history'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bar_chart),
                    title: const Text('Statistics'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/statistics'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Badge(
                      isLabelVisible: pm5Connected,
                      backgroundColor: RowCraftTheme.successGreen,
                      smallSize: 8,
                      child: Icon(
                        pm5Connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                      ),
                    ),
                    title: const Text('Devices'),
                    subtitle: Text(
                      pm5Connected ? 'Connected' : 'Not connected',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/devices'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.emoji_events_outlined),
                    title: const Text('Achievements'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/achievements'),
                  ),
                  const Divider(height: 1),
                  Consumer(
                    builder: (context, ref, _) {
                      final count =
                          ref.watch(pendingSyncCountProvider).value ?? 0;
                      return ListTile(
                        leading: Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          child: const Icon(Icons.cloud_upload_outlined),
                        ),
                        title: const Text('Pending Sync'),
                        subtitle: Text(
                          count == 0 ? 'All synced' : 'Tap to retry',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/pending-sync'),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings'),
                  ),
                ],
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
                  subtitle: Text(isLinked ? 'Connected' : 'Not connected'),
                  trailing: isLinked
                      ? TextButton(
                          onPressed: () async {
                            final service = ref.read(c2LogbookServiceProvider);
                            await service.disconnect();
                            ref.invalidate(c2LinkedProvider);
                          },
                          child: const Text('Disconnect'),
                        )
                      : _c2Linking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton(
                          onPressed: _linkC2,
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
                error: (_, _) => const ListTile(
                  leading: Icon(
                    Icons.error_outline,
                    color: RowCraftTheme.errorRose,
                  ),
                  title: Text('Concept2 Logbook'),
                  subtitle: Text('Error loading status'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Strava link
            Card(
              child: stravaLinkedAsync.when(
                data: (isLinked) => ListTile(
                  leading: Icon(
                    Icons.link,
                    color: isLinked
                        ? const Color(0xFFFC4C02) // Strava brand orange
                        : RowCraftTheme.subtleGrey,
                  ),
                  title: const Text('Strava'),
                  subtitle: Text(isLinked ? 'Connected' : 'Not connected'),
                  trailing: isLinked
                      ? TextButton(
                          onPressed: () async {
                            final service = ref.read(stravaServiceProvider);
                            await service.disconnect();
                            ref.invalidate(stravaLinkedProvider);
                          },
                          child: const Text('Disconnect'),
                        )
                      : _stravaLinking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton(
                          onPressed: _linkStrava,
                          child: const Text('Link'),
                        ),
                ),
                loading: () => const ListTile(
                  leading: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text('Strava'),
                  subtitle: Text('Checking...'),
                ),
                error: (_, _) => const ListTile(
                  leading: Icon(
                    Icons.error_outline,
                    color: RowCraftTheme.errorRose,
                  ),
                  title: Text('Strava'),
                  subtitle: Text('Error loading status'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Plexo sync status — only visible when enabled
            ref
                .watch(plexoEnabledProvider)
                .when(
                  data: (isEnabled) => isEnabled
                      ? const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.sync,
                                color: RowCraftTheme.successGreen,
                              ),
                              title: Text('Plexo'),
                              subtitle: Text('Enabled'),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

            // FTP card
            _FtpCard(),
            const SizedBox(height: 16),

            // Settings section
            Card(
              child: Column(
                children: [
                  profileAsync.when(
                    data: (profile) => ListTile(
                      leading: const Icon(Icons.monitor_weight_outlined),
                      title: const Text('Weight'),
                      subtitle: Text(
                        profile.weightKg != null
                            ? '${(profile.weightKg! * 2.20462).round()} lbs (${profile.weightKg!.toStringAsFixed(1)} kg)'
                            : 'Not set',
                      ),
                      onTap: () => _showEditWeightDialog(context, ref),
                    ),
                    loading: () => const ListTile(
                      leading: Icon(Icons.monitor_weight_outlined),
                      title: Text('Weight'),
                      subtitle: Text('Loading...'),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const Divider(height: 1),
                  profileAsync.when(
                    data: (profile) => ListTile(
                      leading: const Icon(Icons.favorite_outline),
                      title: const Text('Max Heart Rate'),
                      subtitle: Text(
                        profile.maxHeartRate != null
                            ? '${profile.maxHeartRate} bpm'
                            : 'Not set (default: 190)',
                      ),
                      onTap: () => _showEditMaxHrDialog(context, ref),
                    ),
                    loading: () => const ListTile(
                      leading: Icon(Icons.favorite_outline),
                      title: Text('Max Heart Rate'),
                      subtitle: Text('Loading...'),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const Divider(height: 1),
                  // Resting Heart Rate
                  profileAsync.when(
                    data: (profile) => ListTile(
                      leading: const Icon(Icons.monitor_heart_outlined),
                      title: const Text('Resting Heart Rate'),
                      subtitle: Text(
                        profile.restingHeartRate != null
                            ? '${profile.restingHeartRate} bpm'
                            : 'Not set',
                      ),
                      onTap: () => _showEditRestingHrDialog(context, ref),
                    ),
                    loading: () => const ListTile(
                      leading: Icon(Icons.monitor_heart_outlined),
                      title: Text('Resting Heart Rate'),
                      subtitle: Text('Loading...'),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const Divider(height: 1),
                  // Zone System
                  profileAsync.when(
                    data: (profile) {
                      return ListTile(
                        leading: const Icon(Icons.tune),
                        title: const Text('Zone Labels'),
                        subtitle: Text(
                          profile.zoneSystem == ZoneSystem.rowing
                              ? 'Rowing (UT2 / UT1 / AT / TR / AN)'
                              : 'Standard (Z1 / Z2 / Z3 / Z4 / Z5)',
                        ),
                        onTap: () => _showZoneSystemDialog(context, ref),
                      );
                    },
                    loading: () => const ListTile(
                      leading: Icon(Icons.tune),
                      title: Text('Zone Labels'),
                      subtitle: Text('Loading...'),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const Divider(height: 1),
                  ref.watch(appVersionProvider).when(
                    data: (version) => ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About RowCraft'),
                      subtitle: Text('Version $version'),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'RowCraft',
                          applicationVersion: version,
                          applicationLegalese:
                              'Structured rowing workouts for Concept2',
                        );
                      },
                    ),
                    loading: () => const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('About RowCraft'),
                      subtitle: Text('Loading...'),
                    ),
                    error: (_, _) => const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('About RowCraft'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                    onTap: () async {
                      final ok = await launchUrl(
                        Uri.parse('https://rowcraft.app/privacy'),
                        mode: LaunchMode.externalApplication,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open link')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.open_in_new, size: 16),
                    onTap: () async {
                      final ok = await launchUrl(
                        Uri.parse('https://rowcraft.app/terms'),
                        mode: LaunchMode.externalApplication,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open link')),
                        );
                      }
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
            const SizedBox(height: 32),

            // Delete account
            TextButton(
              onPressed: () => _showDeleteAccountDialog(context),
              child: Text(
                'Delete Account',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RowCraftTheme.subtleGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  static void _showEditWeightDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EditWeightDialog(ref: ref),
    );
  }

  static void _showEditMaxHrDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EditMaxHrDialog(ref: ref),
    );
  }

  static void _showEditRestingHrDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EditRestingHrDialog(ref: ref),
    );
  }

  static void _showZoneSystemDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ZoneSystemDialog(ref: ref),
    );
  }

  static void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => const _DeleteAccountDialog(),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Account'),
      content: _isDeleting
          ? const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            )
          : const Text(
              'This will permanently delete your account and all workout data. '
              'This action cannot be undone.',
            ),
      actions: _isDeleting
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: RowCraftTheme.errorRose,
                ),
                onPressed: () async {
                  setState(() => _isDeleting = true);
                  try {
                    final client = Supabase.instance.client;
                    await client.rpc('delete_user_account');
                    // Sign out clears the session; the router's auth redirect
                    // handles navigation to /auth automatically.
                    await ref.read(signOutProvider.future);
                  } catch (_) {
                    if (mounted) setState(() => _isDeleting = false);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Account deletion failed. Please try again.',
                          ),
                          backgroundColor: RowCraftTheme.errorRose,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Delete'),
              ),
            ],
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
                    ProfileScreen.showManualFtpDialog(context, ref);
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
                        ? wattsToPaceStringNoTenths(profile.currentFtpWatts!)
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
              error: (_, _) => Text(
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
                    ...records
                        .take(5)
                        .map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Text(
                                  wattsToPaceStringNoTenths(r.ftpWatts),
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
                          ),
                        ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
  String _wattsPreview = '';
  int? _parsedWatts;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateWattsPreview);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateWattsPreview);
    _controller.dispose();
    super.dispose();
  }

  void _updateWattsPreview() {
    final tenths = parsePace(_controller.text);
    setState(() {
      if (tenths != null) {
        final watts = paceTenthsToWatts(tenths);
        _wattsPreview = '${watts}W';
        _parsedWatts = watts;
      } else {
        _wattsPreview = '';
        _parsedWatts = null;
      }
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
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              hintText: 'Enter pace (m:ss)',
              suffixText: '/500m',
            ),
            autofocus: true,
          ),
          if (_wattsPreview.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _wattsPreview,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: RowCraftTheme.subtleGrey,
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
            if (_parsedWatts != null && _parsedWatts! > 0) {
              final service = widget.ref.read(supabaseServiceProvider);
              final userId = service.currentUserId;
              if (userId != null) {
                await service.saveFtpRecord(
                  FtpRecord(
                    id: '',
                    userId: userId,
                    testedAt: DateTime.now(),
                    ftpWatts: _parsedWatts!,
                    testType: 'manual',
                  ),
                );
                await service.updateProfileFtp(_parsedWatts!);
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

enum _WeightUnit { lbs, kg }

class _EditWeightDialog extends StatefulWidget {
  final WidgetRef ref;
  const _EditWeightDialog({required this.ref});

  @override
  State<_EditWeightDialog> createState() => _EditWeightDialogState();
}

class _EditWeightDialogState extends State<_EditWeightDialog> {
  final _controller = TextEditingController();
  _WeightUnit _unit = _WeightUnit.lbs;

  /// Stored kg value from profile — used as source of truth for conversions
  /// to avoid roundtrip precision loss.
  double? _storedKg;

  @override
  void initState() {
    super.initState();
    final profile = widget.ref.read(profileProvider).value;
    _storedKg = profile?.weightKg;
    if (_storedKg != null) {
      _controller.text = (_storedKg! * 2.20462).round().toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onUnitChanged(_WeightUnit unit) {
    setState(() {
      if (_storedKg != null) {
        // Convert from stored kg to avoid compounding rounding errors
        if (unit == _WeightUnit.lbs) {
          _controller.text = (_storedKg! * 2.20462).round().toString();
        } else {
          _controller.text = _storedKg!.toStringAsFixed(1);
        }
      } else {
        // No stored value — convert from current text
        final current = double.tryParse(_controller.text);
        if (current != null) {
          if (_unit == _WeightUnit.lbs && unit == _WeightUnit.kg) {
            _controller.text = (current * 0.453592).toStringAsFixed(1);
          } else if (_unit == _WeightUnit.kg && unit == _WeightUnit.lbs) {
            _controller.text = (current * 2.20462).round().toString();
          }
        }
      }
      _unit = unit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Weight'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<_WeightUnit>(
            segments: const [
              ButtonSegment(value: _WeightUnit.lbs, label: Text('lbs')),
              ButtonSegment(value: _WeightUnit.kg, label: Text('kg')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => _onUnitChanged(s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Enter weight',
              suffixText: _unit == _WeightUnit.lbs ? 'lbs' : 'kg',
            ),
            autofocus: true,
            onChanged: (_) {
              // Clear stored value so unit switching converts from typed input
              _storedKg = null;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final value = double.tryParse(_controller.text);
            if (value == null || value <= 0) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid weight')),
                );
              }
              return;
            }
            final kg = _unit == _WeightUnit.lbs ? value * 0.453592 : value;
            // Capture ref reads before async gap
            final service = widget.ref.read(supabaseServiceProvider);
            await service.updateProfileWeight(kg);
            if (!context.mounted) return;
            widget.ref.invalidate(profileProvider);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditRestingHrDialog extends StatefulWidget {
  final WidgetRef ref;
  const _EditRestingHrDialog({required this.ref});

  @override
  State<_EditRestingHrDialog> createState() => _EditRestingHrDialogState();
}

class _EditRestingHrDialogState extends State<_EditRestingHrDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = widget.ref.read(profileProvider).value;
    if (profile?.restingHeartRate != null) {
      _controller.text = profile!.restingHeartRate.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Resting Heart Rate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter resting HR',
              suffixText: 'bpm',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Measure first thing in the morning, lying still for 2 min',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: RowCraftTheme.subtleGrey,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final value = int.tryParse(_controller.text);
            if (value == null || value < 30 || value > 120) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Enter a value between 30-120')),
                );
              }
              return;
            }
            final service = widget.ref.read(supabaseServiceProvider);
            try {
              await service.updateProfileRestingHr(value);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Failed to update resting heart rate')),
                );
              }
              return;
            }
            if (!context.mounted) return;
            widget.ref.invalidate(profileProvider);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ZoneSystemDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ZoneSystemDialog({required this.ref});

  @override
  State<_ZoneSystemDialog> createState() => _ZoneSystemDialogState();
}

class _ZoneSystemDialogState extends State<_ZoneSystemDialog> {
  late ZoneSystem _selected;

  @override
  void initState() {
    super.initState();
    final profile = widget.ref.read(profileProvider).value;
    _selected = profile?.zoneSystem ?? ZoneSystem.rowing;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zone Labels'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<ZoneSystem>(
            segments: const [
              ButtonSegment(
                value: ZoneSystem.standard,
                label: Text('Standard'),
              ),
              ButtonSegment(
                value: ZoneSystem.rowing,
                label: Text('Rowing'),
              ),
            ],
            selected: {_selected},
            onSelectionChanged: (s) => setState(() => _selected = s.first),
          ),
          const SizedBox(height: 12),
          Text(
            _selected == ZoneSystem.rowing
                ? 'UT2 / UT1 / AT / TR / AN'
                : 'Z1 / Z2 / Z3 / Z4 / Z5',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: RowCraftTheme.subtleGrey,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final service = widget.ref.read(supabaseServiceProvider);
            try {
              await service.updateProfileZoneSystem(
                  _selected);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Failed to update zone system')),
                );
              }
              return;
            }
            if (!context.mounted) return;
            widget.ref.invalidate(profileProvider);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditMaxHrDialog extends StatefulWidget {
  final WidgetRef ref;
  const _EditMaxHrDialog({required this.ref});

  @override
  State<_EditMaxHrDialog> createState() => _EditMaxHrDialogState();
}

class _EditMaxHrDialogState extends State<_EditMaxHrDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = widget.ref.read(profileProvider).value;
    if (profile?.maxHeartRate != null) {
      _controller.text = profile!.maxHeartRate.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Max Heart Rate'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: 'Enter max HR',
          suffixText: 'bpm',
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
            final value = int.tryParse(_controller.text);
            if (value == null || value < 100 || value > 250) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a value between 100-250')),
                );
              }
              return;
            }
            final service = widget.ref.read(supabaseServiceProvider);
            try {
              await service.updateProfileMaxHr(value);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to update max heart rate')),
                );
              }
              return;
            }
            if (!context.mounted) return;
            widget.ref.invalidate(profileProvider);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
