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
/// Auto-scans for PM5 + HR, auto-connects to saved devices.
/// PM5 is required to continue; HR is optional.
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
      // Try reconnecting to saved devices first, then scan for new ones.
      await notifier.autoReconnect();
      if (!mounted) return;
      final bleState = ref.read(bleProvider);
      if (bleState.pm5ConnectionState != PM5ConnectionState.connected &&
          !bleState.isScanning) {
        notifier.startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bleState = ref.watch(bleProvider);

    final pm5State = bleState.pm5ConnectionState;
    final hrState = bleState.hrConnectionState;
    final pm5Connected = pm5State == PM5ConnectionState.connected;

    // Find first discovered device for each type (for display)
    final firstPm5 = bleState.discoveredPm5Devices.isNotEmpty
        ? bleState.discoveredPm5Devices.first
        : null;
    final firstHr = bleState.discoveredHrDevices.isNotEmpty
        ? bleState.discoveredHrDevices.first
        : null;

    // Find saved devices
    final savedPm5 = bleState.savedDevices
        .where((d) => d.deviceType == 'pm5')
        .toList();
    final savedHr = bleState.savedDevices
        .where((d) => d.deviceType == 'hr')
        .toList();

    return Scaffold(
      backgroundColor: RowCraftTheme.surfaceDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Logo + wordmark
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo_dark.png',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'RowCraft',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Headline
              Text(
                'CONNECT YOUR HARDWARE',
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Turn on your PM5 and heart rate monitor',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: RowCraftTheme.subtleGrey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Device cards
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PM5 card
                    Expanded(
                      child: _DeviceCard(
                        icon: Icons.rowing,
                        label: 'PM5 Rower',
                        badge: 'REQUIRED',
                        badgeColor: RowCraftTheme.errorRose,
                        connectionState: _mapPm5State(pm5State),
                        deviceName: _pm5DeviceName(
                            pm5State, savedPm5, firstPm5),
                        hasDevice:
                            savedPm5.isNotEmpty || firstPm5 != null,
                        connectedColor: RowCraftTheme.successGreen,
                        onConnect: () => _connectPm5(savedPm5, firstPm5),
                        onDisconnect: () =>
                            ref.read(bleProvider.notifier).disconnectPm5(),
                        onRetry: () =>
                            ref.read(bleProvider.notifier).startScan(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // HR card
                    Expanded(
                      child: _DeviceCard(
                        icon: Icons.favorite,
                        label: 'Heart Rate',
                        badge: 'OPTIONAL',
                        badgeColor: RowCraftTheme.subtleGrey,
                        connectionState: _mapHrState(hrState, bleState),
                        deviceName:
                            _hrDeviceName(hrState, savedHr, firstHr),
                        hasDevice:
                            savedHr.isNotEmpty || firstHr != null,
                        connectedColor: RowCraftTheme.errorRose,
                        onConnect: () => _connectHr(savedHr, firstHr),
                        onDisconnect: () =>
                            ref.read(bleProvider.notifier).disconnectHr(),
                        onRetry: () =>
                            ref.read(bleProvider.notifier).startScan(),
                      ),
                    ),
                  ],
                ),
              const Spacer(),

              // Error
              if (bleState.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    bleState.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: RowCraftTheme.errorRose,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Continue button
              SizedBox(
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
                    foregroundColor:
                        pm5Connected ? Colors.black : RowCraftTheme.subtleGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor:
                        RowCraftTheme.surfaceContainerHigh,
                    disabledForegroundColor: RowCraftTheme.subtleGrey,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Skip link
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(
                  'Skip for now',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: RowCraftTheme.subtleGrey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  _CardConnectionState _mapPm5State(PM5ConnectionState state) {
    return switch (state) {
      PM5ConnectionState.scanning => _CardConnectionState.scanning,
      PM5ConnectionState.connecting => _CardConnectionState.connecting,
      PM5ConnectionState.connected => _CardConnectionState.connected,
      PM5ConnectionState.error => _CardConnectionState.notFound,
      PM5ConnectionState.disconnected => _CardConnectionState.idle,
    };
  }

  _CardConnectionState _mapHrState(
      HrConnectionState state, BleState bleState) {
    if (state == HrConnectionState.connected) {
      return _CardConnectionState.connected;
    }
    if (state == HrConnectionState.connecting) {
      return _CardConnectionState.connecting;
    }
    if (bleState.isScanning) return _CardConnectionState.scanning;
    if (state == HrConnectionState.error) return _CardConnectionState.notFound;
    return _CardConnectionState.idle;
  }

  String? _pm5DeviceName(PM5ConnectionState state,
      List<SavedDevice> saved, DiscoveredDevice? discovered) {
    if (state == PM5ConnectionState.connected && saved.isNotEmpty) {
      return saved.first.deviceName;
    }
    if (discovered != null) return discovered.name;
    if (saved.isNotEmpty) return saved.first.deviceName;
    return null;
  }

  String? _hrDeviceName(HrConnectionState state,
      List<SavedDevice> saved, DiscoveredDevice? discovered) {
    if (state == HrConnectionState.connected && saved.isNotEmpty) {
      return saved.first.deviceName;
    }
    if (discovered != null && discovered.name.isNotEmpty) {
      return discovered.name;
    }
    if (saved.isNotEmpty) return saved.first.deviceName;
    return null;
  }

  void _connectPm5(
      List<SavedDevice> saved, DiscoveredDevice? discovered) {
    final notifier = ref.read(bleProvider.notifier);
    if (saved.isNotEmpty) {
      notifier.connectToPm5(saved.first.deviceId,
          deviceName: saved.first.deviceName);
    } else if (discovered != null) {
      notifier.connectToPm5(discovered.id, deviceName: discovered.name);
    }
  }

  void _connectHr(
      List<SavedDevice> saved, DiscoveredDevice? discovered) {
    final notifier = ref.read(bleProvider.notifier);
    if (saved.isNotEmpty) {
      notifier.connectToHrDevice(saved.first.deviceId,
          deviceName: saved.first.deviceName);
    } else if (discovered != null) {
      notifier.connectToHrDevice(discovered.id,
          deviceName: discovered.name.isNotEmpty ? discovered.name : null);
    }
  }
}

// --- Card connection states ---

enum _CardConnectionState {
  idle,
  scanning,
  connecting,
  connected,
  notFound,
}

// --- Device Card Widget ---

class _DeviceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String badge;
  final Color badgeColor;
  final _CardConnectionState connectionState;
  final String? deviceName;
  final bool hasDevice;
  final Color connectedColor;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRetry;

  const _DeviceCard({
    required this.icon,
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.connectionState,
    required this.deviceName,
    required this.hasDevice,
    required this.connectedColor,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = connectionState == _CardConnectionState.connected;

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const SizedBox(height: 12),

          // Icon
          Icon(
            isConnected ? Icons.check_circle : icon,
            size: 40,
            color: isConnected ? connectedColor : RowCraftTheme.subtleGrey,
          ),
          const SizedBox(height: 8),

          // Label
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),

          // Status text
          _StatusText(
            connectionState: connectionState,
            deviceName: deviceName,
            connectedColor: connectedColor,
          ),
          const SizedBox(height: 16),

          // Action button
          _ActionButton(
            connectionState: connectionState,
            hasDevice: hasDevice,
            onConnect: onConnect,
            onDisconnect: onDisconnect,
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final _CardConnectionState connectionState;
  final String? deviceName;
  final Color connectedColor;

  const _StatusText({
    required this.connectionState,
    required this.deviceName,
    required this.connectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: RowCraftTheme.subtleGrey,
    );

    return switch (connectionState) {
      _CardConnectionState.idle => Text(
          'Not connected',
          style: style,
          textAlign: TextAlign.center,
        ),
      _CardConnectionState.scanning => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 6),
            Text('Searching...', style: style),
          ],
        ),
      _CardConnectionState.connecting => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 6),
            Text('Connecting...', style: style),
          ],
        ),
      _CardConnectionState.connected => Text(
          deviceName ?? 'Connected',
          style: theme.textTheme.bodySmall?.copyWith(
            color: connectedColor,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      _CardConnectionState.notFound => Text(
          'No device found',
          style: style,
          textAlign: TextAlign.center,
        ),
    };
  }
}

class _ActionButton extends StatelessWidget {
  final _CardConnectionState connectionState;
  final bool hasDevice;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRetry;

  const _ActionButton({
    required this.connectionState,
    required this.hasDevice,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return switch (connectionState) {
      _CardConnectionState.idle when hasDevice => SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onConnect,
            child: const Text('Connect'),
          ),
        ),
      _CardConnectionState.scanning when hasDevice => SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onConnect,
            child: const Text('Connect'),
          ),
        ),
      _CardConnectionState.idle => SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Scan'),
          ),
        ),
      _CardConnectionState.scanning => const SizedBox.shrink(),
      _CardConnectionState.connecting => const SizedBox(
          height: 36,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      _CardConnectionState.connected => TextButton(
          onPressed: onDisconnect,
          child: const Text('Disconnect'),
        ),
      _CardConnectionState.notFound => TextButton(
          onPressed: onRetry,
          child: const Text('Scan again'),
        ),
    };
  }
}
