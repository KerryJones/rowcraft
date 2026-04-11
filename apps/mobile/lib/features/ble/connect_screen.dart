import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../services/local_db.dart';
import 'ble_provider.dart';
import 'hr_service.dart';
import 'pm5_service.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleState = ref.read(bleProvider);
      // Only auto-scan if not already scanning and not fully connected
      final pm5Connected = bleState.pm5ConnectionState == PM5ConnectionState.connected;
      final hrConnected = bleState.hrConnectionState == HrConnectionState.connected;
      if (!bleState.isScanning && !(pm5Connected && hrConnected)) {
        ref.read(bleProvider.notifier).startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleProvider);
    final theme = Theme.of(context);

    // Show "Remember this device?" dialog when a new device connects
    ref.listen<BleState>(bleProvider, (prev, next) {
      if (next.pendingRememberDevice != null &&
          prev?.pendingRememberDevice == null &&
          mounted) {
        _showRememberDialog(context, next.pendingRememberDevice!);
      }
    });

    final savedIds = bleState.savedDevices.map((d) => d.deviceId).toSet();
    // Show all discovered devices, including saved ones (they appear in both
    // the saved section and the nearby section so users can still forget them).
    final nearbyPm5 = bleState.discoveredPm5Devices.where((d) => !savedIds.contains(d.id)).toList();
    final nearbyHr = bleState.discoveredHrDevices.where((d) => !savedIds.contains(d.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          if (bleState.isScanning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection status bar
          _ConnectionStatusBar(bleState: bleState),
          const SizedBox(height: 16),

          // Saved devices
          if (bleState.savedDevices.isNotEmpty) ...[
            Text('Saved Devices', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...bleState.savedDevices.map((device) => _SavedDeviceTile(
                  device: device,
                  bleState: bleState,
                  discoveredDeviceIds: bleState.discoveredDeviceIds,
                )),
            const SizedBox(height: 24),
          ],

          // Scan button
          Center(
            child: ElevatedButton.icon(
              onPressed: bleState.isScanning
                  ? () => ref.read(bleProvider.notifier).stopScan()
                  : () => ref.read(bleProvider.notifier).startScan(),
              icon: Icon(
                  bleState.isScanning ? Icons.stop : Icons.bluetooth_searching),
              label: Text(bleState.isScanning ? 'Stop Scan' : 'Scan for Devices'),
            ),
          ),
          const SizedBox(height: 24),

          // PM5 devices (exclude already-saved)
          if (nearbyPm5.isNotEmpty) ...[
            Text('Rowers', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...nearbyPm5
                .map((d) => _DiscoveredDeviceTile(
                      device: d,
                      type: 'pm5',
                      isConnecting: bleState.pm5ConnectionState ==
                          PM5ConnectionState.connecting,
                    )),
            const SizedBox(height: 24),
          ],

          // HR devices (exclude already-saved)
          if (nearbyHr.isNotEmpty) ...[
            Text('Heart Rate Monitors', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...nearbyHr
                .map((d) => _DiscoveredDeviceTile(
                      device: d,
                      type: 'hr',
                      isConnecting: bleState.hrConnectionState ==
                          HrConnectionState.connecting,
                    )),
          ],

          // Empty state
          if (!bleState.isScanning &&
              bleState.discoveredPm5Devices.isEmpty &&
              bleState.discoveredHrDevices.isEmpty &&
              bleState.savedDevices.isEmpty) ...[
            const SizedBox(height: 48),
            const Icon(Icons.bluetooth_disabled,
                size: 64, color: RowCraftTheme.subtleGrey),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No devices found.\nTap scan to search for nearby devices.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: RowCraftTheme.subtleGrey,
                ),
              ),
            ),
          ],

          // Error
          if (bleState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: RowCraftTheme.errorRose.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bleState.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RowCraftTheme.errorRose,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRememberDialog(
      BuildContext context, PendingRememberDevice device) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: RowCraftTheme.surfaceContainer,
        title: const Text('Remember device?'),
        content: Text(
          'Remember "${device.deviceName}" for next time?\n\n'
          'If you\'re at a gym, you may not want to save this device.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(bleProvider.notifier).dismissRememberDevice();
            },
            child: const Text('No thanks'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(bleProvider.notifier).confirmRememberDevice();
            },
            child: const Text('Remember'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusBar extends StatelessWidget {
  final BleState bleState;

  const _ConnectionStatusBar({required this.bleState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pm5Connected =
        bleState.pm5ConnectionState == PM5ConnectionState.connected;
    final hrConnected =
        bleState.hrConnectionState == HrConnectionState.connected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // PM5 status row
            Row(
              children: [
                Icon(
                  Icons.rowing,
                  size: 20,
                  color: pm5Connected
                      ? RowCraftTheme.successGreen
                      : RowCraftTheme.subtleGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  pm5Connected ? 'Rower Connected' : 'Rower --',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // HR status row
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  size: 20,
                  color: hrConnected
                      ? RowCraftTheme.successGreen
                      : RowCraftTheme.subtleGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  hrConnected ? 'HR Connected' : 'HR --',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedDeviceTile extends ConsumerWidget {
  final SavedDevice device;
  final BleState bleState;
  final Set<String> discoveredDeviceIds;

  const _SavedDeviceTile({
    required this.device,
    required this.bleState,
    required this.discoveredDeviceIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPm5 = device.deviceType == 'pm5';

    // Per-device connection check: matches THIS specific saved device ID.
    final connectedDeviceId = isPm5
        ? ref.watch(pm5ServiceProvider).connectedDeviceId
        : ref.watch(hrServiceProvider).connectedDeviceId;
    final isThisDeviceConnected = connectedDeviceId == device.deviceId;

    // Per-device connecting check: only show spinner for the specific device
    // being connected to, not for every saved tile of the same type.
    final isThisDeviceConnecting = isPm5
        ? bleState.connectingPm5DeviceId == device.deviceId
        : bleState.connectingHrDeviceId == device.deviceId;

    final isAvailable = discoveredDeviceIds.contains(device.deviceId);
    final showAvailability = bleState.hasScanned && !bleState.isScanning;
    final dimTile = !isThisDeviceConnected &&
        !isThisDeviceConnecting &&
        showAvailability &&
        !isAvailable;

    return Opacity(
      opacity: dimTile ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: RowCraftTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isThisDeviceConnected
                ? RowCraftTheme.successGreen.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: ListTile(
          leading: Icon(
            isPm5 ? Icons.rowing : Icons.favorite,
            color: isThisDeviceConnected
                ? RowCraftTheme.successGreen
                : RowCraftTheme.subtleGrey,
          ),
          title: Text(device.deviceName),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  isPm5 ? 'Ergometer' : 'Heart Rate Monitor',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isThisDeviceConnected && !isThisDeviceConnecting && showAvailability) ...[
                const SizedBox(width: 8),
                if (isAvailable) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: RowCraftTheme.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Available',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: RowCraftTheme.successGreen),
                  ),
                ] else
                  Text(
                    'Not found',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: RowCraftTheme.subtleGrey),
                  ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isThisDeviceConnected) ...[
                TextButton(
                  onPressed: () {
                    if (isPm5) {
                      ref.read(bleProvider.notifier).disconnectPm5();
                    } else {
                      ref.read(bleProvider.notifier).disconnectHr();
                    }
                  },
                  child: const Text('Disconnect'),
                ),
                TextButton(
                  onPressed: () => _confirmForget(context, ref),
                  child: const Text(
                    'Forget',
                    style: TextStyle(color: RowCraftTheme.subtleGrey),
                  ),
                ),
              ] else if (isThisDeviceConnecting)
                const SizedBox(
                  width: 72,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                TextButton(
                  onPressed: () {
                    if (isPm5) {
                      ref.read(bleProvider.notifier).connectToPm5(
                            device.deviceId,
                            deviceName: device.deviceName,
                          );
                    } else {
                      ref.read(bleProvider.notifier).connectToHrDevice(
                            device.deviceId,
                            deviceName: device.deviceName,
                          );
                    }
                  },
                  child: const Text('Connect'),
                ),
                TextButton(
                  onPressed: () => _confirmForget(context, ref),
                  child: const Text(
                    'Forget',
                    style: TextStyle(color: RowCraftTheme.subtleGrey),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmForget(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RowCraftTheme.surfaceContainer,
        title: const Text('Forget device?'),
        content: Text(
          'Forget "${device.deviceName}"? You\'ll need to pair it again next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Disconnect first if this device is currently connected
              final notifier = ref.read(bleProvider.notifier);
              final pm5Id = ref.read(pm5ServiceProvider).connectedDeviceId;
              final hrId = ref.read(hrServiceProvider).connectedDeviceId;
              if (device.deviceId == pm5Id) {
                notifier.disconnectPm5();
              } else if (device.deviceId == hrId) {
                notifier.disconnectHr();
              }
              notifier.removeSavedDevice(device.deviceId);
            },
            child: const Text(
              'Forget',
              style: TextStyle(color: RowCraftTheme.errorRose),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveredDeviceTile extends ConsumerWidget {
  final DiscoveredDevice device;
  final String type;
  final bool isConnecting;

  const _DiscoveredDeviceTile({
    required this.device,
    required this.type,
    required this.isConnecting,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPm5 = type == 'pm5';
    final name = device.name.isNotEmpty ? device.name : device.id;

    return Card(
      child: ListTile(
        leading: Icon(
          isPm5 ? Icons.rowing : Icons.favorite_border,
          color: RowCraftTheme.subtleGrey,
        ),
        title: Text(name),
        subtitle: Text('RSSI: ${device.rssi} dBm'),
        trailing: isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: () {
                  if (isPm5) {
                    ref.read(bleProvider.notifier).connectToPm5(
                          device.id,
                          deviceName: name,
                        );
                  } else {
                    ref.read(bleProvider.notifier).connectToHrDevice(
                          device.id,
                          deviceName: name,
                        );
                  }
                },
                child: const Text('Connect'),
              ),
      ),
    );
  }
}
