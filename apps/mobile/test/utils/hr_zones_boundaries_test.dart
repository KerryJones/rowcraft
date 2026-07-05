// Guards the mobile zone constants against drift from the single source of
// truth in packages/shared/hr-zones.json. hr_zones.dart keeps literal values
// (Dart can't import repo-level JSON at compile time) — this test is what
// makes that copy safe.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rowcraft/utils/hr_zones.dart';

void main() {
  // flutter test runs with cwd = apps/mobile.
  final sharedFile = File('../../packages/shared/hr-zones.json');
  final boundaries = ((jsonDecode(sharedFile.readAsStringSync())
          as Map<String, dynamic>)['boundaries'] as List<dynamic>)
      .cast<num>();

  test('standard zones match packages/shared/hr-zones.json', () {
    expect(standardZones, hasLength(boundaries.length));
    for (var i = 0; i < standardZones.length; i++) {
      expect(standardZones[i].minPct, boundaries[i].toDouble());
      final expectedMax =
          i + 1 < boundaries.length ? boundaries[i + 1].toDouble() : 100.0;
      expect(standardZones[i].maxPct, expectedMax);
    }
  });

  test('rowing zones match packages/shared/hr-zones.json', () {
    expect(rowingZones, hasLength(boundaries.length));
    for (var i = 0; i < rowingZones.length; i++) {
      expect(rowingZones[i].minPct, boundaries[i].toDouble());
      final expectedMax =
          i + 1 < boundaries.length ? boundaries[i + 1].toDouble() : 100.0;
      expect(rowingZones[i].maxPct, expectedMax);
    }
  });
}
