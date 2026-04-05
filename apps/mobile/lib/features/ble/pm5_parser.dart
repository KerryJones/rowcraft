import 'dart:typed_data';

import '../../models/pm5_data.dart';

/// Parses binary BLE notification payloads from the Concept2 PM5.
///
/// The PM5 sends data as little-endian packed bytes. Each characteristic
/// has a fixed layout. We parse each and merge into the running [PM5Data].
///
/// Reference: Concept2 PM5 BLE Communication Protocol
/// Confirmed by ErgometerJS, TrackMyIndoorWorkout, ergarcade/pm5-detail.
class PM5Parser {
  PM5Parser._();

  /// Parse General Status characteristic (CE060031, 19 bytes).
  ///
  /// Layout:
  /// [0-2]  Elapsed time (0.01s) — 3 bytes LE uint
  /// [3-5]  Distance (0.1m) — 3 bytes LE uint
  /// [6]    Workout type
  /// [7]    Interval type
  /// [8]    Workout state
  /// [9]    Rowing state
  /// [10]   Stroke state
  /// [11-13] Total work distance
  /// [14-16] Workout duration
  /// [17]   Workout duration type
  /// [18]   Drag factor
  static PM5Data parseGeneralStatus(Uint8List data, PM5Data current) {
    if (data.length < 6) return current;

    // Elapsed time: 3 bytes, units of 0.01s
    final elapsedCentiseconds =
        data[0] | (data[1] << 8) | (data[2] << 16);
    final elapsedTime =
        Duration(milliseconds: elapsedCentiseconds * 10);

    // Distance: 3 bytes, units of 0.1m
    final distanceTenths =
        data[3] | (data[4] << 8) | (data[5] << 16);
    final distance = distanceTenths / 10.0;

    return current.copyWith(
      elapsedTime: elapsedTime,
      distance: distance,
    );
  }

  /// Parse Additional Status 1 characteristic (CE060032, 17 bytes).
  ///
  /// This is where pace, stroke rate, and heart rate live.
  ///
  /// Layout:
  /// [0-2]  Elapsed time (0.01s)
  /// [3-4]  Speed (uint16 LE, m/s × 1000)
  /// [5]    Stroke rate
  /// [6]    Heart rate (255 = invalid)
  /// [7-8]  Current pace (uint16 LE, centiseconds/500m)
  /// [9-10] Average pace (uint16 LE, centiseconds/500m)
  /// [11-12] Rest distance
  /// [13-15] Rest time
  static PM5Data parseAdditionalStatus(Uint8List data, PM5Data current) {
    if (data.length < 9) return current;

    // Stroke rate
    final strokeRate = data[5];

    // Heart rate (255 means invalid/no HR strap)
    final rawHr = data[6];
    final heartRate = rawHr > 0 && rawHr < 255 ? rawHr : null;

    // Current pace: centiseconds per 500m → tenths per 500m
    final paceCentiseconds = data[7] | (data[8] << 8);
    final pace = paceCentiseconds ~/ 10;

    return current.copyWith(
      strokeRate: strokeRate,
      heartRate: heartRate ?? current.heartRate,
      pace: pace,
      strokeRateUpdated: true,
    );
  }

  /// Parse Additional Status 2 characteristic (CE060033, 9+ bytes).
  ///
  /// Layout:
  /// [0-2]  Elapsed time (0.01s)
  /// [3]    Interval count
  /// [4-5]  Average power (watts, uint16 LE)
  /// [6-7]  Total calories (uint16 LE)
  static PM5Data parseAdditionalStatus2(Uint8List data, PM5Data current) {
    if (data.length < 8) return current;

    final intervalCount = data[3];
    final watts = data[4] | (data[5] << 8);
    final calories = (data[6] | (data[7] << 8)).clamp(0, 9999);

    return current.copyWith(
      intervalCount: intervalCount,
      watts: watts,
      calories: calories,
    );
  }

  /// Parse Stroke Data characteristic (CE060035, 20 bytes).
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
