import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../services/local_db.dart';
import 'ble_provider.dart';
import 'hr_service.dart';
import 'pm5_service.dart';

class ConnectScreen extends ConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final theme = Theme.of(context);

    final savedIds = bleState.savedDevices.map((d) => d.deviceId).toSet();
    final unseenPm5 = bleState.discoveredPm5Devices.where((d) => !savedIds.contains(d.id)).toList();
    final unseenHr = bleState.discoveredHrDevices.where((d) => !savedIds.contains(d.id)).toList();

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
          if (unseenPm5.isNotEmpty) ...[
            Text('PM5 Ergometers', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...unseenPm5
                .map((d) => _DiscoveredDeviceTile(
                      device: d,
                      type: 'pm5',
                      isConnecting: bleState.pm5ConnectionState ==
                          PM5ConnectionState.connecting,
                    )),
            const SizedBox(height: 24),
          ],

          // HR devices (exclude already-saved)
          if (unseenHr.isNotEmpty) ...[
            Text('Heart Rate Monitors', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...unseenHr
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
                  pm5Connected ? 'PM5 Connected' : 'PM5 --',
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
                      ? RowCraftTheme.errorRose
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

  const _SavedDeviceTile({required this.device, required this.bleState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPm5 = device.deviceType == 'pm5';
    final isConnected = isPm5
        ? bleState.pm5ConnectionState == PM5ConnectionState.connected
        : bleState.hrConnectionState == HrConnectionState.connected;
    final isConnecting = isPm5
        ? bleState.pm5ConnectionState == PM5ConnectionState.connecting
        : bleState.hrConnectionState == HrConnectionState.connecting;

    return Card(
      child: ListTile(
        leading: Icon(
          isPm5 ? Icons.rowing : Icons.favorite,
          color: isConnected
              ? (isPm5 ? RowCraftTheme.successGreen : RowCraftTheme.errorRose)
              : RowCraftTheme.subtleGrey,
        ),
        title: Text(device.deviceName),
        subtitle: Text(isPm5 ? 'Ergometer' : 'Heart Rate Monitor'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnected)
              TextButton(
                onPressed: () {
                  if (isPm5) {
                    ref.read(bleProvider.notifier).disconnectPm5();
                  } else {
                    ref.read(bleProvider.notifier).disconnectHr();
                  }
                },
                child: const Text('Disconnect'),
              )
            else if (isConnecting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
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
            if (!isConnected && !isConnecting)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () {
                  ref.read(bleProvider.notifier).removeSavedDevice(device.deviceId);
                },
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
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
