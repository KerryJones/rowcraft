import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'hr_parser.dart';

/// Standard BLE UUIDs for Heart Rate service.
class HrUuids {
  static final Uuid heartRateService = Uuid.parse('0000180D-0000-1000-8000-00805F9B34FB');
  static final Uuid heartRateMeasurement = Uuid.parse('00002A37-0000-1000-8000-00805F9B34FB');
}

/// Connection state for an HR monitor.
enum HrConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Callback invoked when the HR device connection state changes.
typedef HrDeviceConnectedCallback = void Function(String deviceId, String? deviceName);

/// Standalone BLE Heart Rate monitor service.
///
/// Scans for standard BLE HR monitors (Polar, Garmin, Wahoo, etc.),
/// connects, and exposes a stream of heart rate values in BPM.
/// Lifecycle is independent of PM5 — both can be connected simultaneously.
class HrService {
  final FlutterReactiveBle _ble;

  HrService({FlutterReactiveBle? ble})
      : _ble = ble ?? FlutterReactiveBle();

  final _connectionStateController =
      StreamController<HrConnectionState>.broadcast();
  final _heartRateController = StreamController<int>.broadcast();

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamController<DiscoveredDevice>? _scanResultController;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  String? _connectedDeviceId;
  String? _connectedDeviceName;

  /// Called when the device actually connects (for saving to DB).
  HrDeviceConnectedCallback? onDeviceConnected;

  Stream<HrConnectionState> get connectionState =>
      _connectionStateController.stream;

  Stream<int> get heartRateStream => _heartRateController.stream;

  String? get connectedDeviceId => _connectedDeviceId;
  String? get connectedDeviceName => _connectedDeviceName;

  /// Scan for BLE devices advertising the Heart Rate service.
  Stream<DiscoveredDevice> scanForHrDevices() {
    _connectionStateController.add(HrConnectionState.scanning);

    _scanResultController?.close();
    _scanResultController = StreamController<DiscoveredDevice>.broadcast();

    // Scan unfiltered, then filter client-side. Most HR monitors advertise
    // 0x180D but some cheap/older devices only expose it after connection.
    // Name fallback covers common brands: Polar, Garmin HRM straps, Wahoo
    // TICKR, CooSpo, Magene, Scosche.
    _scanSubscription = _ble
        .scanForDevices(
          withServices: [],
          scanMode: ScanMode.lowLatency,
        )
        .where((device) {
          if (device.serviceUuids.contains(HrUuids.heartRateService)) {
            return true;
          }
          final name = device.name.toUpperCase();
          return name.startsWith('POLAR ') ||
              name.startsWith('HRM-') ||
              name.startsWith('TICKR') ||
              name.startsWith('COOSPO') ||
              name.startsWith('MAGENE') ||
              name.startsWith('RHYTHM') ||
              name.startsWith('SCOSCHE');
        })
        .listen(
          (device) => _scanResultController?.add(device),
          onError: (error) {
            _connectionStateController.add(HrConnectionState.error);
            _scanResultController?.addError(error);
          },
        );

    return _scanResultController!.stream;
  }

  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanResultController?.close();
    _scanResultController = null;
  }

  /// Connect to a specific HR monitor device.
  Future<void> connect(String deviceId, {String? deviceName}) async {
    stopScan();
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectionStateController.add(HrConnectionState.connecting);

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
                _connectedDeviceName = deviceName;
                _connectionStateController.add(HrConnectionState.connected);
                _subscribeToHr(deviceId);
                // Notify that connection is confirmed
                onDeviceConnected?.call(deviceId, deviceName);
                break;
              case DeviceConnectionState.disconnected:
                _connectedDeviceId = null;
                _connectedDeviceName = null;
                _connectionStateController
                    .add(HrConnectionState.disconnected);
                _notifySubscription?.cancel();
                break;
              default:
                break;
            }
          },
          onError: (error) {
            _connectionStateController.add(HrConnectionState.error);
          },
        );
  }

  void _subscribeToHr(String deviceId) {
    final char = QualifiedCharacteristic(
      serviceId: HrUuids.heartRateService,
      characteristicId: HrUuids.heartRateMeasurement,
      deviceId: deviceId,
    );

    _notifySubscription = _ble.subscribeToCharacteristic(char).listen(
      (data) {
        final hr = HrParser.parse(Uint8List.fromList(data));
        // Reject values outside physiological range (30-250 BPM)
        if (hr != null && hr >= 30 && hr <= 250) {
          _heartRateController.add(hr);
        }
      },
      onError: (_) {
        // Some devices may briefly drop the characteristic
      },
    );
  }

  /// Disconnect from the current HR monitor.
  Future<void> disconnect() async {
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDeviceId = null;
    _connectedDeviceName = null;
    _connectionStateController.add(HrConnectionState.disconnected);
  }

  void dispose() {
    stopScan();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectionStateController.close();
    _heartRateController.close();
  }
}
