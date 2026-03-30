import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/workout.dart';
import '../../services/local_db.dart';
import '../../services/supabase_service.dart';
import '../ble/ble_provider.dart';
import '../ble/hr_service.dart';
import '../ble/pm5_service.dart';

/// Pre-workout screen that requires PM5 connection before starting.
///
/// Shows workout summary, device connection status, and inline scanning.
/// The START button is disabled until a PM5 is connected. HR is optional.
class PreWorkoutScreen extends ConsumerStatefulWidget {
  final String workoutId;
  final String? planId;
  final int? planWeek;
  final int? planSession;

  const PreWorkoutScreen({
    super.key,
    required this.workoutId,
    this.planId,
    this.planWeek,
    this.planSession,
  });

  @override
  ConsumerState<PreWorkoutScreen> createState() => _PreWorkoutScreenState();
}

class _PreWorkoutScreenState extends ConsumerState<PreWorkoutScreen> {
  Workout? _workout;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
    // Auto-scan for devices on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleState = ref.read(bleProvider);
      if (bleState.pm5ConnectionState == PM5ConnectionState.disconnected &&
          !bleState.isScanning) {
        ref.read(bleProvider.notifier).startScan();
      }
    });
  }

  Future<void> _loadWorkout() async {
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final workout = await supabase.getWorkout(widget.workoutId);
      if (mounted) {
        setState(() {
          _workout = workout;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load workout: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startWorkout() {
    final queryParams = <String, String>{};
    if (widget.planId != null) queryParams['plan'] = widget.planId!;
    if (widget.planWeek != null) {
      queryParams['week'] = widget.planWeek.toString();
    }
    if (widget.planSession != null) {
      queryParams['session'] = widget.planSession.toString();
    }
    final uri = Uri(
      path: '/workout/${widget.workoutId}/active',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleProvider);
    final pm5Connected =
        bleState.pm5ConnectionState == PM5ConnectionState.connected;
    final hrConnected =
        bleState.hrConnectionState == HrConnectionState.connected;
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: RowCraftTheme.surfaceDark,
        appBar: AppBar(title: const Text('Prepare')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: RowCraftTheme.surfaceDark,
        appBar: AppBar(title: const Text('Prepare')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(color: RowCraftTheme.errorRose),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _loadWorkout();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final workout = _workout!;

    return Scaffold(
      backgroundColor: RowCraftTheme.surfaceDark,
      appBar: AppBar(title: const Text('Prepare')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Workout summary
                  _WorkoutSummaryCard(workout: workout),
                  const SizedBox(height: 24),

                  // PM5 Connection (required)
                  _DeviceSection(
                    title: 'PM5 Ergometer',
                    subtitle: 'Required to start',
                    icon: Icons.rowing,
                    isConnected: pm5Connected,
                    isRequired: true,
                    isConnecting: bleState.pm5ConnectionState ==
                        PM5ConnectionState.connecting,
                    connectedColor: RowCraftTheme.successGreen,
                    savedDevices: bleState.savedDevices
                        .where((d) => d.deviceType == 'pm5')
                        .toList(),
                    discoveredDevices: bleState.discoveredPm5Devices,
                    onConnect: (deviceId, deviceName) {
                      ref.read(bleProvider.notifier).connectToPm5(
                            deviceId,
                            deviceName: deviceName,
                          );
                    },
                    onDisconnect: () {
                      ref.read(bleProvider.notifier).disconnectPm5();
                    },
                  ),
                  const SizedBox(height: 16),

                  // HR Monitor (optional)
                  _DeviceSection(
                    title: 'Heart Rate Monitor',
                    subtitle: 'Optional — recommended for training zones',
                    icon: Icons.favorite,
                    isConnected: hrConnected,
                    isRequired: false,
                    isConnecting: bleState.hrConnectionState ==
                        HrConnectionState.connecting,
                    connectedColor: RowCraftTheme.errorRose,
                    savedDevices: bleState.savedDevices
                        .where((d) => d.deviceType == 'hr')
                        .toList(),
                    discoveredDevices: bleState.discoveredHrDevices,
                    onConnect: (deviceId, deviceName) {
                      ref.read(bleProvider.notifier).connectToHrDevice(
                            deviceId,
                            deviceName: deviceName,
                          );
                    },
                    onDisconnect: () {
                      ref.read(bleProvider.notifier).disconnectHr();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Scan button
                  if (!pm5Connected || !hrConnected)
                    Center(
                      child: TextButton.icon(
                        onPressed: bleState.isScanning
                            ? () => ref.read(bleProvider.notifier).stopScan()
                            : () => ref.read(bleProvider.notifier).startScan(),
                        icon: Icon(
                          bleState.isScanning
                              ? Icons.stop
                              : Icons.bluetooth_searching,
                          size: 18,
                        ),
                        label: Text(
                          bleState.isScanning ? 'Stop Scan' : 'Scan for Devices',
                        ),
                      ),
                    ),

                  // Error
                  if (bleState.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      bleState.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: RowCraftTheme.errorRose,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // START button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: RowCraftTheme.surfaceContainer,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!pm5Connected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Connect PM5 to start',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: RowCraftTheme.subtleGrey,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: pm5Connected ? _startWorkout : null,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text(
                        'START WORKOUT',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pm5Connected
                            ? RowCraftTheme.successGreen
                            : RowCraftTheme.surfaceContainerHigh,
                        foregroundColor: pm5Connected
                            ? Colors.white
                            : RowCraftTheme.subtleGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutSummaryCard extends StatelessWidget {
  final Workout workout;

  const _WorkoutSummaryCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = workout.segments;

    // Compute total expanded segments and summary
    int totalSegments = 0;
    for (final seg in segments) {
      totalSegments += seg.repeat;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout.title,
              style: theme.textTheme.headlineMedium,
            ),
            if (workout.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                workout.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: RowCraftTheme.subtleGrey,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _SummaryChip(
                  icon: Icons.segment,
                  label: '$totalSegments intervals',
                ),
                const SizedBox(width: 12),
                _SummaryChip(
                  icon: Icons.category_outlined,
                  label: workout.workoutType.name,
                ),
              ],
            ),
            if (workout.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: workout.tags.map((tag) {
                  return Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: RowCraftTheme.subtleGrey),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A section for connecting a specific device type (PM5 or HR).
class _DeviceSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isConnected;
  final bool isRequired;
  final bool isConnecting;
  final Color connectedColor;
  final List<SavedDevice> savedDevices;
  final List<DiscoveredDevice> discoveredDevices;
  final void Function(String deviceId, String? deviceName) onConnect;
  final VoidCallback onDisconnect;

  const _DeviceSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isConnected,
    required this.isRequired,
    required this.isConnecting,
    required this.connectedColor,
    required this.savedDevices,
    required this.discoveredDevices,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isConnected ? connectedColor : RowCraftTheme.subtleGrey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: theme.textTheme.titleSmall),
                          if (isRequired) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: RowCraftTheme.errorRose.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'REQUIRED',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: RowCraftTheme.errorRose,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected ? 'Connected' : subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isConnected
                              ? connectedColor
                              : RowCraftTheme.subtleGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isConnected)
                  TextButton(
                    onPressed: onDisconnect,
                    child: const Text('Disconnect'),
                  ),
              ],
            ),

            // Saved devices (quick connect)
            if (!isConnected && !isConnecting && savedDevices.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              for (final device in savedDevices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_outline,
                          size: 14, color: RowCraftTheme.subtleGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          device.deviceName,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            onConnect(device.deviceId, device.deviceName),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ),
            ],

            // Discovered devices
            if (!isConnected && !isConnecting && discoveredDevices.isNotEmpty) ...[
              if (savedDevices.isEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
              ],
              const SizedBox(height: 8),
              for (final device in discoveredDevices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth,
                          size: 14, color: RowCraftTheme.subtleGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          device.name.isNotEmpty ? device.name : device.id,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => onConnect(
                          device.id,
                          device.name.isNotEmpty ? device.name : null,
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
