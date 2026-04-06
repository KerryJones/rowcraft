import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../features/ble/ble_provider.dart';
import '../features/ble/pm5_service.dart';

/// AppBar action button showing BLE connection status with a badge.
/// Navigates to the Devices screen on tap.
class BleStatusButton extends ConsumerWidget {
  const BleStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final connected =
        bleState.pm5ConnectionState == PM5ConnectionState.connected;

    return IconButton(
      onPressed: () => context.push('/devices'),
      icon: Badge(
        isLabelVisible: connected,
        backgroundColor: RowCraftTheme.successGreen,
        smallSize: 8,
        child: Icon(
          connected ? Icons.bluetooth_connected : Icons.bluetooth,
        ),
      ),
    );
  }
}
