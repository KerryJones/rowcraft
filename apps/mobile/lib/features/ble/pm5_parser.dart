import 'dart:typed_data';

import '../../models/pm5_data.dart';

/// Parses binary BLE notification payloads from the Concept2 PM5.
///
/// The PM5 sends data as little-endian packed bytes. Each characteristic
/// has a fixed layout. We parse each and merge into the running [PM5Data].
///
/// Reference: Concept2 PM5 BLE Communication Protocol
/// General Status characteristic (CE060031): 19 bytes
/// Additional Status (CE060032): 12 bytes
/// Stroke Data (CE060035): 20 bytes
class PM5Parser {
  PM5Parser._();

  /// Parse General Status characteristic (19 bytes).
  ///
  /// Layout:
  /// [0-2]  Elapsed time (0.01s) — 3 bytes LE uint
  /// [3-5]  Distance (0.1m) — 3 bytes LE uint
  /// [6]    Workout type
  /// [7]    Interval type
  /// [8-9]  Pace (0.01s/500m) — 2 bytes LE uint  (we convert to tenths)
  /// [10]   Stroke rate
  /// [11-12] Heart rate — 1 byte (some FW sends 2)
  /// [13-14] Watts — 2 bytes LE uint
  /// [15-16] Calories — 2 bytes LE uint
  /// [17]   Interval count
  /// [18]   Reserved
  static PM5Data parseGeneralStatus(Uint8List data, PM5Data current) {
    if (data.length < 19) return current;

    // Elapsed time: 3 bytes, units of 0.01s
    final elapsedCentiseconds =
        data[0] | (data[1] << 8) | (data[2] << 16);
    final elapsedTime =
        Duration(milliseconds: elapsedCentiseconds * 10);

    // Distance: 3 bytes, units of 0.1m
    final distanceTenths =
        data[3] | (data[4] << 8) | (data[5] << 16);
    final distance = distanceTenths / 10.0;

    // Pace: 2 bytes, units of 0.01s per 500m → convert to tenths
    final paceCentiseconds = data[8] | (data[9] << 8);
    final pace = paceCentiseconds ~/ 10; // centiseconds → tenths

    // Stroke rate
    final strokeRate = data[10];

    // Heart rate
    final heartRate = data[11] > 0 ? data[11] : null;

    // Watts: 2 bytes
    final watts = data[13] | (data[14] << 8);

    // Calories: 2 bytes
    final calories = data[15] | (data[16] << 8);

    // Interval count
    final intervalCount = data[17];

    return current.copyWith(
      elapsedTime: elapsedTime,
      distance: distance,
      pace: pace,
      strokeRate: strokeRate,
      heartRate: heartRate,
      watts: watts,
      calories: calories,
      intervalCount: intervalCount,
    );
  }

  /// Parse Additional Status characteristic (12 bytes).
  ///
  /// Layout:
  /// [0-2]  Elapsed time (0.01s) — same as general
  /// [3]    Speed (m/s * 100)?  — varies by FW
  /// [4]    Stroke rate (redundant)
  /// [5-6]  Heart rate (some FW)
  /// [7-8]  Pace (redundant)
  /// [9]    Ave pace? / reserved
  /// [10]   Rest time remaining?
  /// [11]   Reserved
  static PM5Data parseAdditionalStatus(Uint8List data, PM5Data current) {
    if (data.length < 12) return current;

    // We mainly use this for heart rate if the general status
    // doesn't provide it (firmware variation)
    final heartRate = data[5] > 0 ? data[5] : null;

    if (heartRate != null && current.heartRate == null) {
      return current.copyWith(heartRate: heartRate);
    }
    return current;
  }

  /// Parse Stroke Data characteristic (20 bytes).
  ///
  /// Layout:
  /// [0-2]  Elapsed time (0.01s)
  /// [3-5]  Distance (0.1m)
  /// [6]    Drive length (0.01m)
  /// [7]    Drive time (0.01s)
  /// [8-9]  Stroke recovery time (0.01s)
  /// [10-11] Stroke distance (0.01m)
  /// [12-13] Peak drive force (0.1 lbs)
  /// [14]   Ave drive force
  /// [15]   Work per stroke (joules)
  /// [16-17] Stroke count — 2 bytes LE uint
  /// [18]   Reserved
  /// [19]   Reserved
  static PM5Data parseStrokeData(Uint8List data, PM5Data current) {
    if (data.length < 18) return current;

    // Stroke count: 2 bytes at offset 16
    final strokeCount = data[16] | (data[17] << 8);

    return current.copyWith(strokeCount: strokeCount);
  }
}
