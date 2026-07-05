// PM5 connection status widgets shared by the workout screens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../ble/ble_provider.dart';
import '../../ble/pm5_service.dart';

// ---------------------------------------------------------------------------
// BLE Status Bar (28px) — PM5 connection only
// ---------------------------------------------------------------------------

class BleStatusBar extends ConsumerWidget {
  const BleStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final connState = bleState.pm5ConnectionState;
    final isConnected = connState == PM5ConnectionState.connected;
    final isReconnecting = connState == PM5ConnectionState.connecting;

    final Color dotColor;
    final Color bgColor;
    final String label;

    if (isConnected) {
      dotColor = RowCraftTheme.successGreen;
      bgColor = RowCraftTheme.surfaceContainer;
      label = 'Rower';
    } else if (isReconnecting) {
      dotColor = RowCraftTheme.warningAmber;
      bgColor = RowCraftTheme.warningAmber.withValues(alpha: 0.15);
      label = 'Reconnecting...';
    } else if (connState == PM5ConnectionState.error) {
      dotColor = RowCraftTheme.errorRose;
      bgColor = RowCraftTheme.errorRose.withValues(alpha: 0.15);
      label = 'Connection error';
    } else {
      dotColor = RowCraftTheme.errorRose;
      bgColor = RowCraftTheme.errorRose.withValues(alpha: 0.15);
      label = 'Rower disconnected';
    }

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: bgColor,
      child: Row(
        children: [
          if (isReconnecting)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: RowCraftTheme.warningAmber,
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isConnected
                  ? RowCraftTheme.metricWhite
                  : dotColor,
            ),
          ),
          if (!isConnected && !isReconnecting) ...[
            const Spacer(),
            GestureDetector(
              onTap: () => ref.read(bleProvider.notifier).autoReconnect(),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  color: RowCraftTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bluetooth Status Icon — compact AppBar indicator (replaces BleStatusBar)
// ---------------------------------------------------------------------------

class BluetoothStatusIcon extends ConsumerWidget {
  const BluetoothStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(bleProvider).pm5ConnectionState;
    final Color color;
    if (connState == PM5ConnectionState.connected) {
      color = RowCraftTheme.successGreen;
    } else if (connState == PM5ConnectionState.connecting) {
      color = RowCraftTheme.warningAmber;
    } else {
      color = RowCraftTheme.errorRose;
    }
    return IconButton(
      icon: Icon(Icons.bluetooth, size: 20, color: color),
      tooltip: 'Devices',
      onPressed: () => GoRouter.of(context).push('/devices'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36),
    );
  }
}
