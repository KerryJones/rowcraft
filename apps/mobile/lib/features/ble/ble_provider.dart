import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pm5_data.dart';
import '../../services/local_db.dart';
import 'ble_permissions.dart';
import 'hr_service.dart';
import 'pm5_service.dart';

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

/// State for the BLE scan/connect UI.
class BleState {
  final PM5ConnectionState pm5ConnectionState;
  final HrConnectionState hrConnectionState;
  final List<DiscoveredDevice> discoveredPm5Devices;
  final List<DiscoveredDevice> discoveredHrDevices;
  final List<SavedDevice> savedDevices;
  final bool hasScanned;
  final String? _error;

  const BleState({
    this.pm5ConnectionState = PM5ConnectionState.disconnected,
    this.hrConnectionState = HrConnectionState.disconnected,
    this.discoveredPm5Devices = const [],
    this.discoveredHrDevices = const [],
    this.savedDevices = const [],
    this.hasScanned = false,
    String? error,
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
  }) {
    return BleState(
      pm5ConnectionState: pm5ConnectionState ?? this.pm5ConnectionState,
      hrConnectionState: hrConnectionState ?? this.hrConnectionState,
      discoveredPm5Devices: discoveredPm5Devices ?? this.discoveredPm5Devices,
      discoveredHrDevices: discoveredHrDevices ?? this.discoveredHrDevices,
      savedDevices: savedDevices ?? this.savedDevices,
      hasScanned: hasScanned ?? this.hasScanned,
      error: error == _sentinel ? _error : error as String?,
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

  @override
  BleState build() {
    final pm5Service = ref.watch(pm5ServiceProvider);
    final hrService = ref.watch(hrServiceProvider);

    _pm5ConnectionSubscription?.cancel();
    _pm5ConnectionSubscription = pm5Service.connectionState.listen((s) {
      state = state.copyWith(pm5ConnectionState: s);
      // Save PM5 device on confirmed connection
      if (s == PM5ConnectionState.connected &&
          pm5Service.connectedDeviceId != null) {
        _saveDevice(
          pm5Service.connectedDeviceId!,
          _pendingPm5Name ?? 'Rower',
          'pm5',
        );
        _pendingPm5Name = null;
      } else if (s == PM5ConnectionState.error) {
        _pendingPm5Name = null;
      }
    });

    _hrConnectionSubscription?.cancel();
    _hrConnectionSubscription = hrService.connectionState.listen((s) {
      state = state.copyWith(hrConnectionState: s);
    });

    // Save HR device on confirmed connection (via callback)
    hrService.onDeviceConnected = (deviceId, deviceName) {
      _saveDevice(deviceId, deviceName ?? 'HR Monitor', 'hr');
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

    // Only reset connection state if not already connected
    final newPm5State =
        state.pm5ConnectionState == PM5ConnectionState.connected
            ? PM5ConnectionState.connected
            : PM5ConnectionState.scanning;

    state = state.copyWith(
      pm5ConnectionState: newPm5State,
      discoveredPm5Devices: [],
      discoveredHrDevices: [],
      hasScanned: false,
      error: null,
    );

    // Scan for PM5 (only if not already connected)
    if (state.pm5ConnectionState != PM5ConnectionState.connected) {
      _pm5ScanSubscription?.cancel();
      _pm5ScanSubscription = pm5Service.scanForPM5().listen(
        (device) {
          if (!pm5Devices.any((d) => d.id == device.id)) {
            pm5Devices.add(device);
            state =
                state.copyWith(discoveredPm5Devices: List.from(pm5Devices));
          }
        },
        onError: (e) {
          state = state.copyWith(
            error: 'Rower scan error: $e',
            pm5ConnectionState: PM5ConnectionState.error,
          );
        },
      );
    }

    // Scan for HR monitors
    _hrScanSubscription?.cancel();
    _hrScanSubscription = hrService.scanForHrDevices().listen(
      (device) {
        if (!hrDevices.any((d) => d.id == device.id)) {
          hrDevices.add(device);
          state = state.copyWith(discoveredHrDevices: List.from(hrDevices));
        }
      },
      onError: (e) {
        state = state.copyWith(
          error: 'HR scan error: $e',
          hrConnectionState: HrConnectionState.error,
        );
      },
    );

    // Auto-stop scan after 10 seconds (cancellable)
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 10), () {
      if (state.isScanning) {
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

    if (state.pm5ConnectionState == PM5ConnectionState.scanning) {
      state = state.copyWith(
          pm5ConnectionState: PM5ConnectionState.disconnected,
          hasScanned: true);
    }
    if (state.hrConnectionState == HrConnectionState.scanning) {
      state = state.copyWith(
          hrConnectionState: HrConnectionState.disconnected,
          hasScanned: true);
    }
  }

  /// Connect to a PM5 device. Device is saved to DB only on confirmed connection.
  Future<void> connectToPm5(String deviceId, {String? deviceName}) async {
    _pendingPm5Name = deviceName;
    stopScan();
    state = state.copyWith(
      pm5ConnectionState: PM5ConnectionState.connecting,
      error: null,
    );

    try {
      await ref.read(pm5ServiceProvider).connect(deviceId);
      // Device saving happens in the connection state listener above
    } catch (e) {
      _pendingPm5Name = null;
      state = state.copyWith(
        pm5ConnectionState: PM5ConnectionState.error,
        error: 'Rower connection failed: $e',
      );
    }
  }

  /// Connect to an HR monitor device. Device is saved to DB only on confirmed connection.
  Future<void> connectToHrDevice(String deviceId,
      {String? deviceName}) async {
    stopScan();
    state = state.copyWith(
      hrConnectionState: HrConnectionState.connecting,
      error: null,
    );

    try {
      await ref
          .read(hrServiceProvider)
          .connect(deviceId, deviceName: deviceName);
      // Device saving happens via the onDeviceConnected callback
    } catch (e) {
      state = state.copyWith(
        hrConnectionState: HrConnectionState.error,
        error: 'HR connection failed: $e',
      );
    }
  }

  /// Disconnect from PM5.
  Future<void> disconnectPm5() async {
    await ref.read(pm5ServiceProvider).disconnect();
    state = state.copyWith(
      pm5ConnectionState: PM5ConnectionState.disconnected,
    );
  }

  /// Disconnect from HR monitor.
  Future<void> disconnectHr() async {
    await ref.read(hrServiceProvider).disconnect();
    state = state.copyWith(
      hrConnectionState: HrConnectionState.disconnected,
    );
  }

  /// Remove a saved device from the database.
  Future<void> removeSavedDevice(String deviceId) async {
    final db = ref.read(localDatabaseProvider);
    await db.removeSavedDevice(deviceId);
    await _loadSavedDevices();
  }

  /// Attempt to auto-reconnect to previously saved devices.
  Future<void> autoReconnect() async {
    final granted = await requestBlePermissions();
    if (!granted) return;

    final db = ref.read(localDatabaseProvider);
    final devices = await db.getSavedDevices();

    for (final device in devices) {
      if (device.deviceType == 'pm5' &&
          state.pm5ConnectionState == PM5ConnectionState.disconnected) {
        try {
          await connectToPm5(device.deviceId, deviceName: device.deviceName);
        } catch (_) {
          // Auto-reconnect failures are silent
        }
      } else if (device.deviceType == 'hr' &&
          state.hrConnectionState == HrConnectionState.disconnected) {
        try {
          await connectToHrDevice(device.deviceId,
              deviceName: device.deviceName);
        } catch (_) {
          // Auto-reconnect failures are silent
        }
      }
    }
  }
}

/// Provider for the BLE notifier.
final bleProvider = NotifierProvider<BleNotifier, BleState>(BleNotifier.new);
