import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pm5_data.dart';
import '../../services/local_db.dart';
import 'ble_permissions.dart';
import 'hr_service.dart';
import 'pm5_service.dart';

/// Merge a newly discovered device into [list], dedup'd by non-empty
/// case-folded name. On collision, keep whichever advertisement has the
/// stronger RSSI (less negative). Devices with empty names fall back to
/// dedup-by-id, so they still appear once each.
///
/// Polar straps rotate their BLE privacy address and advertise on both BLE
/// and ANT+, surfacing the same physical strap as multiple `device.id`s.
/// Name-keyed dedupe collapses those rows for the user without affecting
/// connection logic (which still keys off `device.id`).
///
/// Returns `true` when [list] was modified — callers can skip state churn
/// for redundant adverts during a busy scan.
@visibleForTesting
bool mergeDiscovered(List<DiscoveredDevice> list, DiscoveredDevice d) {
  final name = d.name.trim();
  if (name.isEmpty) {
    if (list.any((e) => e.id == d.id)) return false;
    list.add(d);
    return true;
  }
  final key = name.toLowerCase();
  final i = list.indexWhere((e) => e.name.trim().toLowerCase() == key);
  if (i < 0) {
    list.add(d);
    return true;
  }
  if (d.rssi > list[i].rssi) {
    list[i] = d;
    return true;
  }
  return false;
}

/// Global PM5 service instance.
final pm5ServiceProvider = Provider<PM5Service>((ref) {
  final service = PM5Service();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Global HR service instance.
final hrServiceProvider = Provider<HrService>((ref) {
  final service = HrService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of PM5 connection state.
final pm5ConnectionStateProvider =
    StreamProvider<PM5ConnectionState>((ref) {
  return ref.watch(pm5ServiceProvider).connectionState;
});

/// Stream of HR connection state.
final hrConnectionStateProvider =
    StreamProvider<HrConnectionState>((ref) {
  return ref.watch(hrServiceProvider).connectionState;
});

/// Stream of real-time PM5 data.
final pm5DataStreamProvider = StreamProvider<PM5Data>((ref) {
  return ref.watch(pm5ServiceProvider).pm5DataStream;
});

/// Stream of standalone HR data (BPM).
final hrDataStreamProvider = StreamProvider<int>((ref) {
  return ref.watch(hrServiceProvider).heartRateStream;
});

/// Currently connected PM5 device ID.
final connectedDeviceIdProvider = Provider<String?>((ref) {
  return ref.watch(pm5ServiceProvider).connectedDeviceId;
});

/// Pending device to remember — shown as a dialog prompt after connection.
class PendingRememberDevice {
  final String deviceId;
  final String deviceName;
  final String deviceType;
  const PendingRememberDevice({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
  });
}

/// State for the BLE scan/connect UI.
class BleState {
  final PM5ConnectionState pm5ConnectionState;
  final HrConnectionState hrConnectionState;
  final List<DiscoveredDevice> discoveredPm5Devices;
  final List<DiscoveredDevice> discoveredHrDevices;
  final List<SavedDevice> savedDevices;
  final bool hasScanned;
  final String? _error;
  // Which specific device ID is currently being connected to (null if not connecting).
  final String? connectingPm5DeviceId;
  final String? connectingHrDeviceId;
  /// Set when a device connects and hasn't been saved yet — UI should prompt.
  final PendingRememberDevice? pendingRememberDevice;

  const BleState({
    this.pm5ConnectionState = PM5ConnectionState.disconnected,
    this.hrConnectionState = HrConnectionState.disconnected,
    this.discoveredPm5Devices = const [],
    this.discoveredHrDevices = const [],
    this.savedDevices = const [],
    this.hasScanned = false,
    String? error,
    this.connectingPm5DeviceId,
    this.connectingHrDeviceId,
    this.pendingRememberDevice,
  }) : _error = error;

  String? get error => _error;

  Set<String> get discoveredDeviceIds => {
    ...discoveredPm5Devices.map((d) => d.id),
    ...discoveredHrDevices.map((d) => d.id),
  };

  bool get isScanning =>
      pm5ConnectionState == PM5ConnectionState.scanning ||
      hrConnectionState == HrConnectionState.scanning;

  BleState copyWith({
    PM5ConnectionState? pm5ConnectionState,
    HrConnectionState? hrConnectionState,
    List<DiscoveredDevice>? discoveredPm5Devices,
    List<DiscoveredDevice>? discoveredHrDevices,
    List<SavedDevice>? savedDevices,
    bool? hasScanned,
    Object? error = _sentinel,
    Object? connectingPm5DeviceId = _sentinel,
    Object? connectingHrDeviceId = _sentinel,
    Object? pendingRememberDevice = _sentinel,
  }) {
    return BleState(
      pm5ConnectionState: pm5ConnectionState ?? this.pm5ConnectionState,
      hrConnectionState: hrConnectionState ?? this.hrConnectionState,
      discoveredPm5Devices: discoveredPm5Devices ?? this.discoveredPm5Devices,
      discoveredHrDevices: discoveredHrDevices ?? this.discoveredHrDevices,
      savedDevices: savedDevices ?? this.savedDevices,
      hasScanned: hasScanned ?? this.hasScanned,
      error: error == _sentinel ? _error : error as String?,
      connectingPm5DeviceId: connectingPm5DeviceId == _sentinel
          ? this.connectingPm5DeviceId
          : connectingPm5DeviceId as String?,
      connectingHrDeviceId: connectingHrDeviceId == _sentinel
          ? this.connectingHrDeviceId
          : connectingHrDeviceId as String?,
      pendingRememberDevice: pendingRememberDevice == _sentinel
          ? this.pendingRememberDevice
          : pendingRememberDevice as PendingRememberDevice?,
    );
  }
}

/// Sentinel to distinguish "not passed" from "explicitly null".
const Object _sentinel = Object();

/// Notifier managing BLE scan and connection for PM5 + HR devices.
class BleNotifier extends Notifier<BleState> {
  StreamSubscription<DiscoveredDevice>? _pm5ScanSubscription;
  StreamSubscription<DiscoveredDevice>? _hrScanSubscription;
  StreamSubscription<PM5ConnectionState>? _pm5ConnectionSubscription;
  StreamSubscription<HrConnectionState>? _hrConnectionSubscription;
  Timer? _scanTimer;
  String? _pendingPm5Name;
  bool _autoConnectPm5Attempted = false;
  bool _autoConnectHrAttempted = false;
  bool _scanExtended = false;

  @override
  BleState build() {
    final pm5Service = ref.watch(pm5ServiceProvider);
    final hrService = ref.watch(hrServiceProvider);

    _pm5ConnectionSubscription?.cancel();
    _pm5ConnectionSubscription = pm5Service.connectionState.listen((s) {
      final wasConnecting =
          state.pm5ConnectionState == PM5ConnectionState.connecting;
      state = state.copyWith(pm5ConnectionState: s);
      // Prompt to remember PM5 device on confirmed connection
      if (s == PM5ConnectionState.connected &&
          pm5Service.connectedDeviceId != null) {
        final deviceId = pm5Service.connectedDeviceId!;
        final alreadySaved =
            state.savedDevices.any((d) => d.deviceId == deviceId);
        if (alreadySaved) {
          _pendingPm5Name = null;
        } else {
          state = state.copyWith(
            pendingRememberDevice: PendingRememberDevice(
              deviceId: deviceId,
              deviceName: _pendingPm5Name ?? 'Rower',
              deviceType: 'pm5',
            ),
          );
          _pendingPm5Name = null;
        }
      } else if (s == PM5ConnectionState.error ||
          (s == PM5ConnectionState.disconnected && wasConnecting)) {
        // Connection attempt failed (BLE timeout fires `disconnected` from
        // `connecting`) — allow auto-connect to retry on next advertisement.
        _pendingPm5Name = null;
        _autoConnectPm5Attempted = false;
      }
    });

    _hrConnectionSubscription?.cancel();
    _hrConnectionSubscription = hrService.connectionState.listen((s) {
      final wasConnecting =
          state.hrConnectionState == HrConnectionState.connecting;
      state = state.copyWith(hrConnectionState: s);
      if (s == HrConnectionState.error ||
          (s == HrConnectionState.disconnected && wasConnecting)) {
        _autoConnectHrAttempted = false;
      }
    });

    // Prompt to remember HR device on confirmed connection (via callback)
    hrService.onDeviceConnected = (deviceId, deviceName) {
      final alreadySaved =
          state.savedDevices.any((d) => d.deviceId == deviceId);
      if (!alreadySaved) {
        state = state.copyWith(
          pendingRememberDevice: PendingRememberDevice(
            deviceId: deviceId,
            deviceName: deviceName ?? 'HR Monitor',
            deviceType: 'hr',
          ),
        );
      }
    };

    ref.onDispose(() {
      _pm5ScanSubscription?.cancel();
      _hrScanSubscription?.cancel();
      _pm5ConnectionSubscription?.cancel();
      _hrConnectionSubscription?.cancel();
      _scanTimer?.cancel();
    });

    // Load saved devices on init
    Future.microtask(() => _loadSavedDevices());

    return const BleState();
  }

  Future<void> _saveDevice(
      String deviceId, String deviceName, String deviceType) async {
    final db = ref.read(localDatabaseProvider);
    await db.saveDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
    );
    await _loadSavedDevices();
  }

  Future<void> _loadSavedDevices() async {
    final db = ref.read(localDatabaseProvider);
    final devices = await db.getSavedDevices();
    state = state.copyWith(savedDevices: devices);
  }

  /// Start scanning for both PM5 and HR devices simultaneously.
  Future<void> startScan() async {
    final granted = await requestBlePermissions();
    if (!granted) {
      state = state.copyWith(
        error: 'Bluetooth permissions are required to scan for devices. '
            'Please grant permissions in Settings.',
      );
      return;
    }

    final pm5Service = ref.read(pm5ServiceProvider);
    final hrService = ref.read(hrServiceProvider);
    final pm5Devices = <DiscoveredDevice>[];
    final hrDevices = <DiscoveredDevice>[];
    _autoConnectPm5Attempted = false;
    _autoConnectHrAttempted = false;
    _scanExtended = false;

    final pm5Connected =
        state.pm5ConnectionState == PM5ConnectionState.connected;
    final hrConnected =
        state.hrConnectionState == HrConnectionState.connected;

    state = state.copyWith(
      pm5ConnectionState:
          pm5Connected ? PM5ConnectionState.connected : PM5ConnectionState.scanning,
      hrConnectionState:
          hrConnected ? HrConnectionState.connected : HrConnectionState.scanning,
      discoveredPm5Devices: [],
      discoveredHrDevices: [],
      hasScanned: false,
      error: null,
    );

    // Always scan for PM5 — even when one is connected, the user may have
    // multiple rowers saved and needs to see which are nearby.
    _pm5ScanSubscription?.cancel();
    _pm5ScanSubscription = pm5Service.scanForPM5().listen(
      (device) {
        if (mergeDiscovered(pm5Devices, device)) {
          state = state.copyWith(discoveredPm5Devices: List.from(pm5Devices));
        }
        if (!_autoConnectPm5Attempted &&
            state.pm5ConnectionState == PM5ConnectionState.scanning &&
            state.connectingPm5DeviceId == null) {
          SavedDevice? matched;
          for (final d in state.savedDevices) {
            if (d.deviceType == 'pm5' && d.deviceId == device.id) {
              matched = d;
              break;
            }
          }
          if (matched != null) {
            _autoConnectPm5Attempted = true;
            connectToPm5(device.id,
                deviceName: matched.deviceName, stopScanning: false);
          }
        }
      },
      onError: (e) {
        if (!pm5Connected) {
          state = state.copyWith(
            error: 'Rower scan error: $e',
            pm5ConnectionState: PM5ConnectionState.error,
          );
        }
      },
    );

    // Scan for HR monitors
    _hrScanSubscription?.cancel();
    _hrScanSubscription = hrService.scanForHrDevices().listen(
      (device) {
        if (mergeDiscovered(hrDevices, device)) {
          state = state.copyWith(discoveredHrDevices: List.from(hrDevices));
        }
        if (!_autoConnectHrAttempted &&
            state.hrConnectionState == HrConnectionState.scanning &&
            state.connectingHrDeviceId == null) {
          final discoveredName = device.name.trim().toLowerCase();
          SavedDevice? matched;
          if (discoveredName.isNotEmpty) {
            for (final d in state.savedDevices) {
              if (d.deviceType == 'hr' &&
                  d.deviceName.trim().toLowerCase() == discoveredName) {
                matched = d;
                break;
              }
            }
          }
          if (matched != null) {
            _autoConnectHrAttempted = true;
            connectToHrDevice(device.id,
                deviceName:
                    device.name.isNotEmpty ? device.name : matched.deviceName,
                stopScanning: false);
          }
        }
      },
      onError: (e) {
        state = state.copyWith(
          error: 'HR scan error: $e',
          hrConnectionState: HrConnectionState.error,
        );
      },
    );

    // Auto-stop scan after 10 seconds; extends once if a saved device hasn't
    // been seen yet (slow-to-wake PM5 gets ~20s before "No devices found").
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 10), () {
      if (!state.isScanning) return;
      // Extend only when an attempt hasn't fired yet — connecting/connected
      // state doesn't persist the "already tried" fact across transitions.
      final needsMoreTime = !_scanExtended &&
          ((state.pm5ConnectionState == PM5ConnectionState.scanning &&
                  !_autoConnectPm5Attempted &&
                  state.savedDevices.any((d) => d.deviceType == 'pm5')) ||
              (state.hrConnectionState == HrConnectionState.scanning &&
                  !_autoConnectHrAttempted &&
                  state.savedDevices.any((d) => d.deviceType == 'hr')));
      if (needsMoreTime) {
        _scanExtended = true;
        _scanTimer = Timer(const Duration(seconds: 10), () {
          if (state.isScanning) stopScan();
        });
      } else {
        stopScan();
      }
    });
  }

  /// Stop all scanning.
  void stopScan() {
    _pm5ScanSubscription?.cancel();
    _pm5ScanSubscription = null;
    _hrScanSubscription?.cancel();
    _hrScanSubscription = null;
    _scanTimer?.cancel();
    _scanTimer = null;

    ref.read(pm5ServiceProvider).stopScan();
    ref.read(hrServiceProvider).stopScan();

    state = state.copyWith(
      hasScanned: true,
      pm5ConnectionState: state.pm5ConnectionState == PM5ConnectionState.scanning
          ? PM5ConnectionState.disconnected
          : null,
      hrConnectionState: state.hrConnectionState == HrConnectionState.scanning
          ? HrConnectionState.disconnected
          : null,
    );
  }

  /// Connect to a PM5 device. Device is saved to DB only on confirmed connection.
  Future<void> connectToPm5(String deviceId,
      {String? deviceName, bool stopScanning = true}) async {
    _pendingPm5Name = deviceName;
    if (stopScanning) stopScan();
    state = state.copyWith(
      pm5ConnectionState: PM5ConnectionState.connecting,
      connectingPm5DeviceId: deviceId,
      error: null,
    );

    try {
      await ref.read(pm5ServiceProvider).connect(deviceId);
      // Device saving happens in the connection state listener above
      state = state.copyWith(connectingPm5DeviceId: null);
    } catch (e) {
      _pendingPm5Name = null;
      state = state.copyWith(
        pm5ConnectionState: PM5ConnectionState.error,
        connectingPm5DeviceId: null,
        error: 'Rower connection failed: $e',
      );
    }
  }

  /// Connect to an HR monitor device. Device is saved to DB only on confirmed connection.
  Future<void> connectToHrDevice(String deviceId,
      {String? deviceName, bool stopScanning = true}) async {
    if (stopScanning) stopScan();
    state = state.copyWith(
      hrConnectionState: HrConnectionState.connecting,
      connectingHrDeviceId: deviceId,
      error: null,
    );

    try {
      await ref
          .read(hrServiceProvider)
          .connect(deviceId, deviceName: deviceName);
      // Device saving happens via the onDeviceConnected callback
      state = state.copyWith(connectingHrDeviceId: null);
    } catch (e) {
      state = state.copyWith(
        hrConnectionState: HrConnectionState.error,
        connectingHrDeviceId: null,
        error: 'HR connection failed: $e',
      );
    }
  }

  /// Disconnect from PM5.
  Future<void> disconnectPm5() async {
    await ref.read(pm5ServiceProvider).disconnect();
    state = state.copyWith(
      pm5ConnectionState: PM5ConnectionState.disconnected,
      connectingPm5DeviceId: null,
    );
  }

  /// Disconnect from HR monitor.
  Future<void> disconnectHr() async {
    await ref.read(hrServiceProvider).disconnect();
    state = state.copyWith(
      hrConnectionState: HrConnectionState.disconnected,
      connectingHrDeviceId: null,
    );
  }

  /// Confirm saving the pending device to the database.
  Future<void> confirmRememberDevice() async {
    final pending = state.pendingRememberDevice;
    if (pending == null) return;
    await _saveDevice(pending.deviceId, pending.deviceName, pending.deviceType);
    state = state.copyWith(pendingRememberDevice: null);
  }

  /// Dismiss the remember-device prompt without saving.
  void dismissRememberDevice() {
    state = state.copyWith(pendingRememberDevice: null);
  }

  /// Remove a saved device from the database.
  Future<void> removeSavedDevice(String deviceId) async {
    final db = ref.read(localDatabaseProvider);
    await db.removeSavedDevice(deviceId);
    await _loadSavedDevices();
  }

  /// Attempt to auto-reconnect to previously saved devices by scanning and
  /// connecting on discovery — avoids blind connect to non-advertising devices.
  Future<void> autoReconnect() async {
    final granted = await requestBlePermissions();
    if (!granted) return;
    await _loadSavedDevices();
    await startScan();
  }
}

/// Provider for the BLE notifier.
final bleProvider = NotifierProvider<BleNotifier, BleState>(BleNotifier.new);
