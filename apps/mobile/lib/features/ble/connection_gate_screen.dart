import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../services/local_db.dart';
import 'ble_provider.dart';
import 'hr_service.dart';
import 'pm5_service.dart';

/// Connection gate shown on app launch before the main tab shell.
/// Shows discovered devices as a selectable list — never auto-connects
/// to discovered devices without user confirmation.
///
/// When [isManagement] is true the screen shows an AppBar with a back button
/// and hides the Continue/Skip footer — used for the in-app /devices route.
class ConnectionGateScreen extends ConsumerStatefulWidget {
  const ConnectionGateScreen({super.key, this.isManagement = false});

  final bool isManagement;

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
      final pm5Connected =
          bleState.pm5ConnectionState == PM5ConnectionState.connected;
      final hrConnected =
          bleState.hrConnectionState == HrConnectionState.connected;
      final fullyConnected = pm5Connected && hrConnected;
      if (!bleState.isScanning &&
          (widget.isManagement ? !fullyConnected : !pm5Connected)) {
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

    void forgetDevice(SavedDevice device) {
      ref.read(bleProvider.notifier).removeSavedDevice(device.deviceId);
    }

    final deviceList = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // PM5 section
        _DeviceSection(
          icon: Icons.rowing,
          label: 'Rower',
          badge: 'REQUIRED',
          badgeColor: RowCraftTheme.errorRose,
          connectedColor: RowCraftTheme.successGreen,
          isConnected: pm5Connected,
          isConnecting: bleState.pm5ConnectionState ==
              PM5ConnectionState.connecting,
          connectingDeviceId: bleState.connectingPm5DeviceId,
          isScanning: bleState.isScanning,
          connectedDeviceName: pm5Connected
              ? _connectedName(savedPm5,
                  ref.watch(pm5ServiceProvider).connectedDeviceId)
              : null,
          savedDevices: savedPm5,
          discoveredDeviceIds: bleState.discoveredDeviceIds,
          hasScanned: bleState.hasScanned,
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
          onForget: forgetDevice,
          onScan: () => ref.read(bleProvider.notifier).startScan(),
        ),
        const SizedBox(height: 12),

        // HR section
        _DeviceSection(
          icon: Icons.favorite,
          label: 'Heart Rate',
          badge: 'OPTIONAL',
          badgeColor: RowCraftTheme.subtleGrey,
          connectedColor: RowCraftTheme.successGreen,
          isConnected:
              bleState.hrConnectionState == HrConnectionState.connected,
          isConnecting:
              bleState.hrConnectionState == HrConnectionState.connecting,
          connectingDeviceId: bleState.connectingHrDeviceId,
          isScanning: bleState.isScanning,
          connectedDeviceName: bleState.hrConnectionState ==
                  HrConnectionState.connected
              ? _connectedName(
                  savedHr, ref.watch(hrServiceProvider).connectedDeviceId)
              : null,
          savedDevices: savedHr,
          discoveredDeviceIds: bleState.discoveredDeviceIds,
          hasScanned: bleState.hasScanned,
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
                  deviceName: device.name.isNotEmpty ? device.name : null,
                );
          },
          onDisconnect: () =>
              ref.read(bleProvider.notifier).disconnectHr(),
          onForget: forgetDevice,
          onScan: () => ref.read(bleProvider.notifier).startScan(),
        ),
      ],
    );

    if (widget.isManagement) {
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
        body: Column(
          children: [
            Expanded(child: deviceList),
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
          ],
        ),
      );
    }

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
                      SvgPicture.asset('assets/logo_gold.svg', height: 40),
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
            Expanded(child: deviceList),

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
                    disabledBackgroundColor: RowCraftTheme.surfaceContainerHigh,
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
  /// ID of the specific device currently being connected to for this type.
  final String? connectingDeviceId;
  final bool isScanning;
  final String? connectedDeviceName;
  final List<SavedDevice> savedDevices;
  final Set<String> discoveredDeviceIds;
  final bool hasScanned;
  final List<DiscoveredDevice> discoveredDevices;
  final void Function(SavedDevice) onConnectSaved;
  final void Function(DiscoveredDevice) onConnectDiscovered;
  final VoidCallback onDisconnect;
  final void Function(SavedDevice) onForget;
  final VoidCallback onScan;

  const _DeviceSection({
    required this.icon,
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.connectedColor,
    required this.isConnected,
    required this.isConnecting,
    this.connectingDeviceId,
    required this.isScanning,
    required this.connectedDeviceName,
    required this.savedDevices,
    required this.discoveredDeviceIds,
    required this.hasScanned,
    required this.discoveredDevices,
    required this.onConnectSaved,
    required this.onConnectDiscovered,
    required this.onDisconnect,
    required this.onForget,
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
              // Only show header spinner when connecting to a discovered device;
              // saved device rows show their own per-row spinner.
              else if (isConnecting &&
                  !savedDevices.any((d) => d.deviceId == connectingDeviceId))
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
                isAvailable: hasScanned && !isScanning
                    ? discoveredDeviceIds.contains(device.deviceId)
                    : null,
                isConnecting: connectingDeviceId == device.deviceId,
                onTap: connectingDeviceId == device.deviceId
                    ? null
                    : () => onConnectSaved(device),
                onForget: (name) => _confirmForget(context, name, device),
              ),
          ],

          // Discovered devices list
          if (!isConnected &&
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

  void _confirmForget(
      BuildContext context, String name, SavedDevice device) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RowCraftTheme.surfaceContainer,
        title: const Text('Forget device?'),
        content: Text(
          'Forget "$name"? You\'ll need to pair it again next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onForget(device);
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

/// A tappable device row in the discovery list.
class _DeviceRow extends StatelessWidget {
  final String name;
  final String? subtitle;
  final bool? isAvailable;
  final bool isConnecting;
  final VoidCallback? onTap;
  /// When provided, a delete icon is shown that triggers a forget confirmation.
  final void Function(String name)? onForget;

  const _DeviceRow({
    required this.name,
    required this.subtitle,
    this.isAvailable,
    this.isConnecting = false,
    required this.onTap,
    this.onForget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimRow = isAvailable == false;
    return Opacity(
      opacity: dimRow ? 0.5 : 1.0,
      child: InkWell(
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
                    if (isAvailable != null)
                      Row(
                        children: [
                          if (isAvailable!) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: RowCraftTheme.successGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Available',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: RowCraftTheme.successGreen,
                                  fontSize: 11),
                            ),
                          ] else
                            Text(
                              'Not found',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: RowCraftTheme.subtleGrey,
                                  fontSize: 11),
                            ),
                        ],
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
              else if (onForget != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: RowCraftTheme.subtleGrey),
                  onPressed: () => onForget!(name),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                const Icon(Icons.add, size: 20,
                    color: RowCraftTheme.subtleGrey),
            ],
          ),
        ),
      ),
    );
  }
}
