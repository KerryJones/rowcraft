import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../features/ble/ble_provider.dart';
import '../features/ble/pm5_service.dart';

/// Shows a modal bottom sheet requiring PM5 connection before starting a workout.
/// Auto-dismisses and calls [onConnected] when PM5 connects.
Future<void> showConnectionRequiredSheet({
  required BuildContext context,
  required VoidCallback onConnected,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: RowCraftTheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (sheetContext) {
      return _ConnectionRequiredContent(
        onConnected: onConnected,
      );
    },
  );
}

class _ConnectionRequiredContent extends ConsumerStatefulWidget {
  final VoidCallback onConnected;

  const _ConnectionRequiredContent({required this.onConnected});

  @override
  ConsumerState<_ConnectionRequiredContent> createState() =>
      _ConnectionRequiredContentState();
}

class _ConnectionRequiredContentState
    extends ConsumerState<_ConnectionRequiredContent> {
  bool _didConnect = false;

  @override
  void initState() {
    super.initState();
    // Auto-start scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleState = ref.read(bleProvider);
      if (!bleState.isScanning &&
          bleState.pm5ConnectionState == PM5ConnectionState.disconnected) {
        ref.read(bleProvider.notifier).startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bleState = ref.watch(bleProvider);
    final pm5Connected =
        bleState.pm5ConnectionState == PM5ConnectionState.connected;

    // Auto-dismiss on connection
    if (pm5Connected && !_didConnect) {
      _didConnect = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onConnected();
        }
      });
    }

    final savedPm5 =
        bleState.savedDevices.where((d) => d.deviceType == 'pm5').toList();
    final savedPm5Ids = savedPm5.map((d) => d.deviceId).toSet();
    final discoveredPm5 = bleState.discoveredPm5Devices
        .where((d) => !savedPm5Ids.contains(d.id))
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RowCraftTheme.subtleGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            const Icon(
              Icons.bluetooth_disabled,
              size: 48,
              color: RowCraftTheme.warningAmber,
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Rower Not Connected',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your rower to start this workout.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: RowCraftTheme.subtleGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Saved PM5 devices
            if (savedPm5.isNotEmpty) ...[
              for (final device in savedPm5)
                _DeviceRow(
                  icon: Icons.bookmark_outline,
                  name: device.deviceName,
                  isConnecting: bleState.pm5ConnectionState ==
                      PM5ConnectionState.connecting,
                  onConnect: () {
                    ref.read(bleProvider.notifier).connectToPm5(
                          device.deviceId,
                          deviceName: device.deviceName,
                        );
                  },
                ),
              const Divider(height: 24),
            ],

            // Discovered PM5 devices
            if (discoveredPm5.isNotEmpty) ...[
              for (final device in discoveredPm5)
                _DeviceRow(
                  icon: Icons.bluetooth,
                  name: device.name.isNotEmpty ? device.name : device.id,
                  isConnecting: bleState.pm5ConnectionState ==
                      PM5ConnectionState.connecting,
                  onConnect: () {
                    ref.read(bleProvider.notifier).connectToPm5(
                          device.id,
                          deviceName:
                              device.name.isNotEmpty ? device.name : null,
                        );
                  },
                ),
              const SizedBox(height: 8),
            ],

            // Scan button
            if (bleState.pm5ConnectionState != PM5ConnectionState.connecting)
              TextButton.icon(
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

            // Connecting spinner
            if (bleState.pm5ConnectionState == PM5ConnectionState.connecting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Connecting...'),
                  ],
                ),
              ),

            // Error
            if (bleState.error != null) ...[
              const SizedBox(height: 8),
              Text(
                bleState.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RowCraftTheme.errorRose,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 16),

            // Cancel
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final bool isConnecting;
  final VoidCallback onConnect;

  const _DeviceRow({
    required this.icon,
    required this.name,
    required this.isConnecting,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: RowCraftTheme.subtleGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: isConnecting ? null : onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: RowCraftTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
