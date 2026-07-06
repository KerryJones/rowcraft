// Tests for BleNotifier's drop-recovery reconnect loop:
// - direct reconnect to the last-connected PM5 succeeds on the fast path
// - bounded retry: gives up after maxReconnectAttempts and surfaces an error
// - reentrant autoReconnect calls are no-ops while a loop is running
// - autoReconnect with no session devices falls back to a plain scan

import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rowcraft/features/ble/ble_provider.dart';
import 'package:rowcraft/features/ble/hr_service.dart';
import 'package:rowcraft/features/ble/pm5_service.dart';
import 'package:rowcraft/services/local_db.dart';

class _FakePM5Service extends Fake implements PM5Service {
  final connectionController =
      StreamController<PM5ConnectionState>.broadcast();

  String? _connectedDeviceId;
  final connectCalls = <String>[];
  int scanCalls = 0;

  /// When true, connect() emits `connected`; otherwise it goes silent
  /// (simulating a PM5 that is off / out of range).
  bool connectSucceeds = true;

  /// When true, connect() emits `error` immediately (simulating a BLE
  /// stack that rejects the connection right away).
  bool connectEmitsError = false;

  @override
  Stream<PM5ConnectionState> get connectionState =>
      connectionController.stream;

  @override
  String? get connectedDeviceId => _connectedDeviceId;

  @override
  bool get intentionalDisconnect => false;

  @override
  Stream<DiscoveredDevice> scanForPM5() {
    scanCalls++;
    return const Stream.empty();
  }

  @override
  void stopScan() {}

  @override
  Future<void> connect(String deviceId) async {
    connectCalls.add(deviceId);
    if (connectEmitsError) {
      connectionController.add(PM5ConnectionState.error);
    } else if (connectSucceeds) {
      _connectedDeviceId = deviceId;
      connectionController.add(PM5ConnectionState.connected);
    }
  }

  /// Simulate an established connection followed by an unexpected drop.
  void simulateConnected(String deviceId) {
    _connectedDeviceId = deviceId;
    connectionController.add(PM5ConnectionState.connected);
  }

  void simulateDrop() {
    _connectedDeviceId = null;
    connectionController.add(PM5ConnectionState.disconnected);
  }

  @override
  void dispose() {
    connectionController.close();
  }
}

class _FakeHrService extends Fake implements HrService {
  final connectionController = StreamController<HrConnectionState>.broadcast();

  @override
  HrDeviceConnectedCallback? onDeviceConnected;

  @override
  Stream<HrConnectionState> get connectionState => connectionController.stream;

  @override
  bool get intentionalDisconnect => false;

  @override
  Stream<DiscoveredDevice> scanForHrDevices() => const Stream.empty();

  @override
  void stopScan() {}

  @override
  void dispose() {
    connectionController.close();
  }
}

class _FakeLocalDatabase extends Fake implements LocalDatabase {
  List<SavedDevice> devices = [];

  @override
  Future<List<SavedDevice>> getSavedDevices() async => devices;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePM5Service pm5;
  late _FakeHrService hr;
  late _FakeLocalDatabase db;
  late ProviderContainer container;

  setUp(() {
    // Shrink the loop so tests run in milliseconds.
    BleNotifier.reconnectAttemptWindow = const Duration(milliseconds: 60);
    BleNotifier.reconnectPollInterval = const Duration(milliseconds: 5);
    BleNotifier.reconnectInitialBackoff = const Duration(milliseconds: 10);
    BleNotifier.reconnectMaxBackoff = const Duration(milliseconds: 20);
    BleNotifier.maxReconnectAttempts = 2;

    pm5 = _FakePM5Service();
    hr = _FakeHrService();
    db = _FakeLocalDatabase();
    container = ProviderContainer(overrides: [
      pm5ServiceProvider.overrideWithValue(pm5),
      hrServiceProvider.overrideWithValue(hr),
      localDatabaseProvider.overrideWithValue(db),
    ]);
  });

  tearDown(() {
    container.dispose();
    pm5.dispose();
    hr.dispose();
    // Restore defaults for any suite sharing the isolate.
    BleNotifier.reconnectAttemptWindow = const Duration(seconds: 12);
    BleNotifier.reconnectPollInterval = const Duration(milliseconds: 250);
    BleNotifier.reconnectInitialBackoff = const Duration(seconds: 2);
    BleNotifier.reconnectMaxBackoff = const Duration(seconds: 30);
    BleNotifier.maxReconnectAttempts = 5;
  });

  Future<void> establishAndDrop() async {
    container.read(bleProvider); // build the notifier + listeners
    await pumpEventQueue();
    pm5.simulateConnected('PM5-1');
    await pumpEventQueue();
    expect(container.read(bleProvider).pm5ConnectionState,
        PM5ConnectionState.connected);
    pm5.simulateDrop();
    await pumpEventQueue();
    expect(container.read(bleProvider).pm5ConnectionState,
        PM5ConnectionState.disconnected);
  }

  test('direct reconnect to last PM5 succeeds on the fast path', () async {
    await establishAndDrop();

    await container.read(bleProvider.notifier).autoReconnect();
    await pumpEventQueue();

    expect(pm5.connectCalls, ['PM5-1']);
    expect(container.read(bleProvider).pm5ConnectionState,
        PM5ConnectionState.connected);
    expect(container.read(bleProvider).error, isNull);
    // Fast path succeeded — no scan needed.
    expect(pm5.scanCalls, 0);
  });

  test('gives up after bounded attempts and surfaces an error', () async {
    await establishAndDrop();
    pm5.connectSucceeds = false;

    await container.read(bleProvider.notifier).autoReconnect();

    // One direct attempt + one scan per attempt round.
    expect(pm5.connectCalls.length, BleNotifier.maxReconnectAttempts);
    expect(pm5.scanCalls, greaterThanOrEqualTo(1));
    expect(
      container.read(bleProvider).error,
      contains('Could not reconnect'),
    );
  });

  test('an immediate connect error short-circuits the attempt window',
      () async {
    // Widen the window so the difference between waiting it out and
    // short-circuiting is unambiguous in wall-clock terms.
    BleNotifier.reconnectAttemptWindow = const Duration(milliseconds: 200);
    await establishAndDrop();
    pm5.connectEmitsError = true; // connect() rejects right away

    final sw = Stopwatch()..start();
    await container.read(bleProvider.notifier).autoReconnect();
    sw.stop();

    // Every attempt still runs (one direct connect per round) and the loop
    // gives up with an error.
    expect(pm5.connectCalls.length, BleNotifier.maxReconnectAttempts);
    expect(container.read(bleProvider).error, contains('Could not reconnect'));

    // With the fast-fail, only the scan waits consume the window
    // (~2 × 200ms). Without it, the direct-connect waits would double that
    // to ~800ms. A 650ms bound sits cleanly between the two.
    expect(sw.elapsedMilliseconds, lessThan(650));
  });

  test('reentrant autoReconnect calls are ignored while a loop runs',
      () async {
    await establishAndDrop();
    pm5.connectSucceeds = false;

    final notifier = container.read(bleProvider.notifier);
    final first = notifier.autoReconnect();
    final second = notifier.autoReconnect(); // should no-op immediately
    await Future.wait([first, second]);

    // Exactly one loop ran: attempts match a single loop's budget.
    expect(pm5.connectCalls.length, BleNotifier.maxReconnectAttempts);
  });

  test('falls back to a plain scan when nothing was connected this session',
      () async {
    container.read(bleProvider);
    await pumpEventQueue();

    await container.read(bleProvider.notifier).autoReconnect();
    await pumpEventQueue();

    // No direct-connect candidates — just kicks off a scan.
    expect(pm5.connectCalls, isEmpty);
    expect(pm5.scanCalls, 1);
  });
}
