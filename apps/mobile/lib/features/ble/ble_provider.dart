import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pm5_data.dart';
import 'pm5_service.dart';

/// Global PM5 service instance.
final pm5ServiceProvider = Provider<PM5Service>((ref) {
  final service = PM5Service();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of PM5 connection state.
final pm5ConnectionStateProvider =
    StreamProvider<PM5ConnectionState>((ref) {
  return ref.watch(pm5ServiceProvider).connectionState;
});

/// Stream of real-time PM5 data.
final pm5DataStreamProvider = StreamProvider<PM5Data>((ref) {
  return ref.watch(pm5ServiceProvider).pm5DataStream;
});

/// Currently connected device ID.
final connectedDeviceIdProvider = Provider<String?>((ref) {
  return ref.watch(pm5ServiceProvider).connectedDeviceId;
});

/// State for the BLE scan/connect UI.
class BleState {
  final PM5ConnectionState connectionState;
  final List<DiscoveredDevice> discoveredDevices;
  final String? error;

  const BleState({
    this.connectionState = PM5ConnectionState.disconnected,
    this.discoveredDevices = const [],
    this.error,
  });

  BleState copyWith({
    PM5ConnectionState? connectionState,
    List<DiscoveredDevice>? discoveredDevices,
    String? error,
  }) {
    return BleState(
      connectionState: connectionState ?? this.connectionState,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      error: error,
    );
  }
}

/// Notifier managing BLE scan and connection.
class BleNotifier extends Notifier<BleState> {
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<PM5ConnectionState>? _connectionSubscription;

  @override
  BleState build() {
    final service = ref.watch(pm5ServiceProvider);

    // Listen to connection state changes
    _connectionSubscription?.cancel();
    _connectionSubscription = service.connectionState.listen((connState) {
      state = state.copyWith(connectionState: connState);
    });

    ref.onDispose(() {
      _scanSubscription?.cancel();
      _connectionSubscription?.cancel();
    });

    return const BleState();
  }

  /// Start scanning for PM5 devices.
  void startScan() {
    final service = ref.read(pm5ServiceProvider);
    final devices = <DiscoveredDevice>[];

    state = state.copyWith(
      connectionState: PM5ConnectionState.scanning,
      discoveredDevices: [],
      error: null,
    );

    _scanSubscription?.cancel();
    _scanSubscription = service.scanForPM5().listen(
      (device) {
        // Avoid duplicates
        if (!devices.any((d) => d.id == device.id)) {
          devices.add(device);
          state = state.copyWith(discoveredDevices: List.from(devices));
        }
      },
      onError: (e) {
        state = state.copyWith(
          error: 'Scan error: ${e.toString()}',
          connectionState: PM5ConnectionState.error,
        );
      },
    );

    // Auto-stop scan after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (state.connectionState == PM5ConnectionState.scanning) {
        stopScan();
      }
    });
  }

  /// Stop scanning.
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    final service = ref.read(pm5ServiceProvider);
    service.stopScan();

    if (state.connectionState == PM5ConnectionState.scanning) {
      state = state.copyWith(
          connectionState: PM5ConnectionState.disconnected);
    }
  }

  /// Connect to a discovered PM5 device.
  Future<void> connectToDevice(String deviceId) async {
    stopScan();
    state = state.copyWith(
      connectionState: PM5ConnectionState.connecting,
      error: null,
    );

    try {
      final service = ref.read(pm5ServiceProvider);
      await service.connect(deviceId);
    } catch (e) {
      state = state.copyWith(
        connectionState: PM5ConnectionState.error,
        error: 'Connection failed: ${e.toString()}',
      );
    }
  }

  /// Disconnect from the current PM5.
  Future<void> disconnect() async {
    final service = ref.read(pm5ServiceProvider);
    await service.disconnect();
    state = state.copyWith(
      connectionState: PM5ConnectionState.disconnected,
    );
  }
}

/// Provider for the BLE notifier.
final bleProvider = NotifierProvider<BleNotifier, BleState>(BleNotifier.new);
