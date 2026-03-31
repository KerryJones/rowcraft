import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../services/local_db.dart';
import 'ble_provider.dart';
import 'hr_service.dart';
import 'pm5_service.dart';

/// Connection gate shown on app launch before the main tab shell.
/// Shows discovered devices as a selectable list — never auto-connects
/// to discovered devices without user confirmation.
class ConnectionGateScreen extends ConsumerStatefulWidget {
  const ConnectionGateScreen({super.key});

  @override
  ConsumerState<ConnectionGateScreen> createState() =>
      _ConnectionGateScreenState();
}

class _ConnectionGateScreenState extends ConsumerState<ConnectionGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(bleProvider.notifier);
      await notifier.autoReconnect();
      if (!mounted) return;
      final bleState = ref.read(bleProvider);
      if (bleState.pm5ConnectionState != PM5ConnectionState.connected &&
          !bleState.isScanning) {
        notifier.startScan();
      }
    });
  }

  /// Look up connected device name from saved devices by ID.
  String? _connectedName(List<SavedDevice> saved, String? connectedId) {
    if (connectedId == null) return null;
    for (final d in saved) {
      if (d.deviceId == connectedId) return d.deviceName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bleState = ref.watch(bleProvider);
    final pm5Connected =
        bleState.pm5ConnectionState == PM5ConnectionState.connected;

    final savedPm5 =
        bleState.savedDevices.where((d) => d.deviceType == 'pm5').toList();
    final savedHr =
        bleState.savedDevices.where((d) => d.deviceType == 'hr').toList();
    final savedPm5Ids = savedPm5.map((d) => d.deviceId).toSet();
    final savedHrIds = savedHr.map((d) => d.deviceId).toSet();

    return Scaffold(
      backgroundColor: RowCraftTheme.surfaceDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/logo_dark.png',
                          width: 40, height: 40),
                      const SizedBox(width: 10),
                      Text('RowCraft',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CONNECT YOUR HARDWARE',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select your devices below',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: RowCraftTheme.subtleGrey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable device sections
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // PM5 section
                  _DeviceSection(
                    icon: Icons.rowing,
                    label: 'PM5 Rower',
                    badge: 'REQUIRED',
                    badgeColor: RowCraftTheme.errorRose,
                    connectedColor: RowCraftTheme.successGreen,
                    isConnected: pm5Connected,
                    isConnecting: bleState.pm5ConnectionState ==
                        PM5ConnectionState.connecting,
                    isScanning: bleState.isScanning,
                    connectedDeviceName: pm5Connected
                        ? _connectedName(savedPm5,
                            ref.watch(pm5ServiceProvider).connectedDeviceId)
                        : null,
                    savedDevices: savedPm5,
                    discoveredDevices: bleState.discoveredPm5Devices
                        .where((d) => !savedPm5Ids.contains(d.id))
                        .toList(),
                    onConnectSaved: (device) {
                      ref.read(bleProvider.notifier).connectToPm5(
                            device.deviceId,
                            deviceName: device.deviceName,
                          );
                    },
                    onConnectDiscovered: (device) {
                      ref.read(bleProvider.notifier).connectToPm5(
                            device.id,
                            deviceName: device.name,
                          );
                    },
                    onDisconnect: () =>
                        ref.read(bleProvider.notifier).disconnectPm5(),
                    onScan: () =>
                        ref.read(bleProvider.notifier).startScan(),
                  ),
                  const SizedBox(height: 12),

                  // HR section
                  _DeviceSection(
                    icon: Icons.favorite,
                    label: 'Heart Rate',
                    badge: 'OPTIONAL',
                    badgeColor: RowCraftTheme.subtleGrey,
                    connectedColor: RowCraftTheme.errorRose,
                    isConnected: bleState.hrConnectionState ==
                        HrConnectionState.connected,
                    isConnecting: bleState.hrConnectionState ==
                        HrConnectionState.connecting,
                    isScanning: bleState.isScanning,
                    connectedDeviceName:
                        bleState.hrConnectionState ==
                                HrConnectionState.connected
                            ? _connectedName(savedHr,
                                ref.watch(hrServiceProvider).connectedDeviceId)
                            : null,
                    savedDevices: savedHr,
                    discoveredDevices: bleState.discoveredHrDevices
                        .where((d) => !savedHrIds.contains(d.id))
                        .toList(),
                    onConnectSaved: (device) {
                      ref.read(bleProvider.notifier).connectToHrDevice(
                            device.deviceId,
                            deviceName: device.deviceName,
                          );
                    },
                    onConnectDiscovered: (device) {
                      ref.read(bleProvider.notifier).connectToHrDevice(
                            device.id,
                            deviceName:
                                device.name.isNotEmpty ? device.name : null,
                          );
                    },
                    onDisconnect: () =>
                        ref.read(bleProvider.notifier).disconnectHr(),
                    onScan: () =>
                        ref.read(bleProvider.notifier).startScan(),
                  ),
                ],
              ),
            ),

            // Error
            if (bleState.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  bleState.error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: RowCraftTheme.errorRose),
                  textAlign: TextAlign.center,
                ),
              ),

            // Continue + Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: pm5Connected ? () => context.go('/') : null,
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: Text(
                    'CONTINUE',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: pm5Connected ? Colors.black : null,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pm5Connected
                        ? RowCraftTheme.successGreen
                        : RowCraftTheme.surfaceContainerHigh,
                    foregroundColor: pm5Connected
                        ? Colors.black
                        : RowCraftTheme.subtleGrey,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    disabledBackgroundColor:
                        RowCraftTheme.surfaceContainerHigh,
                    disabledForegroundColor: RowCraftTheme.subtleGrey,
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text('Skip for now',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: RowCraftTheme.subtleGrey)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A device type section with header + selectable device list.
class _DeviceSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String badge;
  final Color badgeColor;
  final Color connectedColor;
  final bool isConnected;
  final bool isConnecting;
  final bool isScanning;
  final String? connectedDeviceName;
  final List<SavedDevice> savedDevices;
  final List<DiscoveredDevice> discoveredDevices;
  final void Function(SavedDevice) onConnectSaved;
  final void Function(DiscoveredDevice) onConnectDiscovered;
  final VoidCallback onDisconnect;
  final VoidCallback onScan;

  const _DeviceSection({
    required this.icon,
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.connectedColor,
    required this.isConnected,
    required this.isConnecting,
    required this.isScanning,
    required this.connectedDeviceName,
    required this.savedDevices,
    required this.discoveredDevices,
    required this.onConnectSaved,
    required this.onConnectDiscovered,
    required this.onDisconnect,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDevices = savedDevices.isNotEmpty || discoveredDevices.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: RowCraftTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? connectedColor.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle : icon,
                size: 24,
                color: isConnected
                    ? connectedColor
                    : RowCraftTheme.subtleGrey,
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              if (isConnected)
                TextButton(
                  onPressed: onDisconnect,
                  child: const Text('Disconnect'),
                )
              else if (isConnecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),

          // Connected state
          if (isConnected) ...[
            const SizedBox(height: 4),
            Text(
              connectedDeviceName ?? 'Connected',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: connectedColor),
            ),
          ],

          // Scanning indicator
          if (!isConnected && !isConnecting && isScanning) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                const SizedBox(width: 8),
                Text('Searching for devices...',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: RowCraftTheme.subtleGrey)),
              ],
            ),
          ],

          // Saved devices list
          if (!isConnected &&
              !isConnecting &&
              savedDevices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Saved',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: RowCraftTheme.subtleGrey,
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            for (final device in savedDevices)
              _DeviceRow(
                name: device.deviceName.isNotEmpty
                    ? device.deviceName
                    : device.deviceId,
                subtitle: null,
                onTap: () => onConnectSaved(device),
              ),
          ],

          // Discovered devices list
          if (!isConnected &&
              !isConnecting &&
              discoveredDevices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Nearby',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: RowCraftTheme.subtleGrey,
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            for (final device in discoveredDevices)
              _DeviceRow(
                name: device.name.isNotEmpty ? device.name : device.id,
                subtitle: 'RSSI: ${device.rssi} dBm',
                onTap: () => onConnectDiscovered(device),
              ),
          ],

          // No devices found
          if (!isConnected &&
              !isConnecting &&
              !isScanning &&
              !hasDevices) ...[
            const SizedBox(height: 12),
            Text('No devices found',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: RowCraftTheme.subtleGrey)),
          ],

          // Scan button (when not scanning)
          if (!isConnected && !isConnecting && !isScanning) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.bluetooth_searching, size: 16),
                label: const Text('Scan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable device row in the discovery list.
class _DeviceRow extends StatelessWidget {
  final String name;
  final String? subtitle;
  final VoidCallback onTap;

  const _DeviceRow({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: RowCraftTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.bluetooth, size: 16,
                color: RowCraftTheme.primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.bodyMedium),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: RowCraftTheme.subtleGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20,
                color: RowCraftTheme.subtleGrey),
          ],
        ),
      ),
    );
  }
}

