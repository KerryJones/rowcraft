import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../../models/pm5_data.dart';
import 'pm5_parser.dart';

/// PM5 BLE Service UUIDs.
class PM5Uuids {
  /// Discovery service — advertised in scan response packets.
  static final Uuid discoveryService =
      Uuid.parse('CE060000-43E5-11E4-916C-0800200C9A66');
  static final Uuid rowingService =
      Uuid.parse('CE060030-43E5-11E4-916C-0800200C9A66');
  static final Uuid generalStatusChar =
      Uuid.parse('CE060031-43E5-11E4-916C-0800200C9A66');
  static final Uuid additionalStatusChar =
      Uuid.parse('CE060032-43E5-11E4-916C-0800200C9A66');
  static final Uuid additionalStatus2Char =
      Uuid.parse('CE060033-43E5-11E4-916C-0800200C9A66');
  static final Uuid strokeDataChar =
      Uuid.parse('CE060035-43E5-11E4-916C-0800200C9A66');
  static final Uuid additionalStrokeDataChar =
      Uuid.parse('CE060036-43E5-11E4-916C-0800200C9A66');

  // CSAFE control
  static final Uuid controlService =
      Uuid.parse('CE060020-43E5-11E4-916C-0800200C9A66');
  static final Uuid csafeTxChar =
      Uuid.parse('CE060021-43E5-11E4-916C-0800200C9A66');
  static final Uuid csafeRxChar =
      Uuid.parse('CE060022-43E5-11E4-916C-0800200C9A66');
}

/// Connection state of the PM5.
enum PM5ConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Manages BLE connection and data streaming from a Concept2 PM5.
///
/// Uses `flutter_reactive_ble` for scan/connect/notify. All PM5 data
/// comes via characteristic notifications — never reads (PM5 returns
/// junk on reads).
class PM5Service {
  final FlutterReactiveBle _ble;

  PM5Service({FlutterReactiveBle? ble})
      : _ble = ble ?? FlutterReactiveBle();

  final _connectionStateController =
      StreamController<PM5ConnectionState>.broadcast();
  final _pm5DataController = StreamController<PM5Data>.broadcast();

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  final List<StreamSubscription<List<int>>> _notifySubscriptions = [];

  String? _connectedDeviceId;
  PM5Data _latestData = const PM5Data.zero();

  /// Stream of connection state changes.
  Stream<PM5ConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Stream of real-time PM5 data from BLE notifications.
  Stream<PM5Data> get pm5DataStream => _pm5DataController.stream;

  /// The latest PM5 data snapshot.
  PM5Data get latestData => _latestData;

  /// Currently connected device ID, if any.
  String? get connectedDeviceId => _connectedDeviceId;

  /// Scan for nearby PM5 devices.
  Stream<DiscoveredDevice> scanForPM5() {
    _connectionStateController.add(PM5ConnectionState.scanning);

    final controller = StreamController<DiscoveredDevice>.broadcast();

    // Scan unfiltered: PM5 advertises CE060000 in the scan response packet,
    // which some Android BLE stacks don't match against scan filters.
    // Filter client-side by advertised service UUID or device name pattern.
    _scanSubscription = _ble
        .scanForDevices(
          withServices: [],
          scanMode: ScanMode.lowLatency,
        )
        .where((device) =>
            device.serviceUuids.contains(PM5Uuids.discoveryService) ||
            RegExp(r'^PM\d\s').hasMatch(device.name))
        .listen(
          (device) => controller.add(device),
          onError: (error) {
            _connectionStateController.add(PM5ConnectionState.error);
            controller.addError(error);
          },
        );

    return controller.stream;
  }

  /// Stop scanning.
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// Connect to a specific PM5 device and start receiving data.
  Future<void> connect(String deviceId) async {
    stopScan();
    _connectionStateController.add(PM5ConnectionState.connecting);

    _connectionSubscription = _ble
        .connectToDevice(
          id: deviceId,
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen(
          (update) async {
            switch (update.connectionState) {
              case DeviceConnectionState.connected:
                _connectedDeviceId = deviceId;
                _connectionStateController.add(PM5ConnectionState.connected);
                await _subscribeToCharacteristics(deviceId);
                break;
              case DeviceConnectionState.disconnected:
                _connectedDeviceId = null;
                _connectionStateController
                    .add(PM5ConnectionState.disconnected);
                _cancelNotifySubscriptions();
                break;
              default:
                break;
            }
          },
          onError: (error) {
            _connectionStateController.add(PM5ConnectionState.error);
          },
        );
  }

  /// Disconnect from the current PM5.
  Future<void> disconnect() async {
    _cancelNotifySubscriptions();
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDeviceId = null;
    _connectionStateController.add(PM5ConnectionState.disconnected);
  }

  /// Subscribe to PM5 rowing data characteristics (notifications only).
  Future<void> _subscribeToCharacteristics(String deviceId) async {
    // General Status (primary data: time, distance, pace, stroke rate, watts, calories, HR)
    _subscribeToChar(deviceId, PM5Uuids.generalStatusChar, (data) {
      final parsed = PM5Parser.parseGeneralStatus(
        Uint8List.fromList(data),
        _latestData,
      );
      _latestData = parsed;
      _pm5DataController.add(parsed);
    });

    // Additional Status (stroke count, etc.)
    _subscribeToChar(deviceId, PM5Uuids.additionalStatusChar, (data) {
      final parsed = PM5Parser.parseAdditionalStatus(
        Uint8List.fromList(data),
        _latestData,
      );
      _latestData = parsed;
      _pm5DataController.add(parsed);
    });

    // Stroke Data
    _subscribeToChar(deviceId, PM5Uuids.strokeDataChar, (data) {
      final parsed = PM5Parser.parseStrokeData(
        Uint8List.fromList(data),
        _latestData,
      );
      _latestData = parsed;
      _pm5DataController.add(parsed);
    });
  }

  void _subscribeToChar(
    String deviceId,
    Uuid charUuid,
    void Function(List<int>) onData,
  ) {
    final char = QualifiedCharacteristic(
      serviceId: PM5Uuids.rowingService,
      characteristicId: charUuid,
      deviceId: deviceId,
    );

    final sub = _ble.subscribeToCharacteristic(char).listen(
          onData,
          onError: (e) {
            // Silently handle characteristic errors — some PM5 firmware
            // versions don't expose all characteristics.
          },
        );
    _notifySubscriptions.add(sub);
  }

  void _cancelNotifySubscriptions() {
    for (final sub in _notifySubscriptions) {
      sub.cancel();
    }
    _notifySubscriptions.clear();
  }

  /// Send a CSAFE command frame to the PM5.
  Future<void> sendCsafeCommand(Uint8List frame, String deviceId) async {
    final char = QualifiedCharacteristic(
      serviceId: PM5Uuids.controlService,
      characteristicId: PM5Uuids.csafeTxChar,
      deviceId: deviceId,
    );
    await _ble.writeCharacteristicWithoutResponse(char, value: frame);
  }

  /// Dispose all resources.
  void dispose() {
    stopScan();
    _cancelNotifySubscriptions();
    _connectionSubscription?.cancel();
    _connectionStateController.close();
    _pm5DataController.close();
  }
}
