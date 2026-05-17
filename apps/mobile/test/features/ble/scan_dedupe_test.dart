import 'dart:typed_data';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/features/ble/ble_provider.dart';

DiscoveredDevice _device({
  required String id,
  required String name,
  required int rssi,
}) {
  return DiscoveredDevice(
    id: id,
    name: name,
    serviceData: const {},
    manufacturerData: Uint8List(0),
    rssi: rssi,
    serviceUuids: const [],
  );
}

void main() {
  group('mergeDiscovered', () {
    test('appends a device the list has not seen and reports a change', () {
      final list = <DiscoveredDevice>[];
      final changed = mergeDiscovered(
          list, _device(id: 'a', name: 'Polar H10', rssi: -70));

      expect(changed, isTrue);
      expect(list, hasLength(1));
      expect(list.single.id, 'a');
    });

    test('same name + different ids collapses to one row '
        '(strongest RSSI wins)', () {
      final list = <DiscoveredDevice>[];
      mergeDiscovered(list,
          _device(id: 'aa', name: 'Polar H10 219B5527', rssi: -85));
      final changed = mergeDiscovered(list,
          _device(id: 'bb', name: 'Polar H10 219B5527', rssi: -60));

      expect(changed, isTrue);
      expect(list, hasLength(1));
      expect(list.single.id, 'bb', reason: 'stronger RSSI should win');
      expect(list.single.rssi, -60);
    });

    test('weaker advertisement on collision is ignored and reports no change',
        () {
      final list = <DiscoveredDevice>[];
      mergeDiscovered(list,
          _device(id: 'aa', name: 'Polar H10', rssi: -55));
      final changed = mergeDiscovered(list,
          _device(id: 'bb', name: 'Polar H10', rssi: -90));

      expect(changed, isFalse);
      expect(list, hasLength(1));
      expect(list.single.id, 'aa');
      expect(list.single.rssi, -55);
    });

    test('name match is case-insensitive and whitespace-tolerant', () {
      final list = <DiscoveredDevice>[];
      mergeDiscovered(list,
          _device(id: 'aa', name: 'Polar H10', rssi: -80));
      mergeDiscovered(list,
          _device(id: 'bb', name: '  polar h10 ', rssi: -50));

      expect(list, hasLength(1));
      expect(list.single.id, 'bb');
    });

    test('different names stay as separate rows', () {
      final list = <DiscoveredDevice>[];
      mergeDiscovered(list,
          _device(id: 'aa', name: 'Polar H10', rssi: -70));
      mergeDiscovered(list,
          _device(id: 'bb', name: 'Wahoo TICKR', rssi: -70));

      expect(list, hasLength(2));
    });

    test('empty-name devices fall back to dedup-by-id', () {
      final list = <DiscoveredDevice>[];
      mergeDiscovered(list, _device(id: 'aa', name: '', rssi: -70));
      final changed =
          mergeDiscovered(list, _device(id: 'aa', name: '', rssi: -50));

      expect(changed, isFalse);
      expect(list, hasLength(1));
      // Empty-name fallback does not replace by RSSI — keeps the first row.
      expect(list.single.rssi, -70);
    });

    test('empty-name devices with different ids stay separate', () {
      final list = <DiscoveredDevice>[];
      mergeDiscovered(list, _device(id: 'aa', name: '', rssi: -70));
      mergeDiscovered(list, _device(id: 'bb', name: '', rssi: -70));

      expect(list, hasLength(2));
    });

    test('mix of named and unnamed devices coexist', () {
      final list = <DiscoveredDevice>[];
      mergeDiscovered(list,
          _device(id: 'aa', name: 'Polar H10', rssi: -70));
      mergeDiscovered(list, _device(id: 'bb', name: '', rssi: -70));
      mergeDiscovered(list,
          _device(id: 'cc', name: 'Polar H10', rssi: -90));

      expect(list, hasLength(2));
      expect(list.where((d) => d.name == 'Polar H10'), hasLength(1));
      expect(list.where((d) => d.name.isEmpty), hasLength(1));
    });
  });
}
