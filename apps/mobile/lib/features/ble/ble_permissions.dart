import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Requests all permissions required for BLE scanning on the current platform.
///
/// On Android API 31+, requests bluetoothScan + bluetoothConnect.
/// On Android API 23-30, requests location (required for BLE scanning).
/// On iOS, returns true (handled by Info.plist).
///
/// Returns `true` if all required permissions are granted.
Future<bool> requestBlePermissions() async {
  if (!Platform.isAndroid) return true;

  final statuses = await [
    Permission.location,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
  ].request();

  return statuses.values.every((s) => s.isGranted || s.isLimited);
}
