import 'dart:typed_data';

/// Parses BLE Heart Rate Measurement characteristic (0x2A37).
///
/// Per Bluetooth SIG Heart Rate Service spec:
/// Byte 0: Flags
///   - Bit 0: HR format (0 = uint8, 1 = uint16)
///   - Bits 1-2: Sensor contact status
///   - Bit 3: Energy expended present
///   - Bit 4: RR-interval present
/// Byte 1 (or 1-2): Heart rate value
class HrParser {
  HrParser._();

  /// Parse a Heart Rate Measurement notification payload.
  /// Returns heart rate in BPM, or null if data is too short.
  static int? parse(Uint8List data) {
    if (data.isEmpty) return null;

    final flags = data[0];
    final isUint16 = (flags & 0x01) == 1;

    if (isUint16) {
      if (data.length < 3) return null;
      return data[1] | (data[2] << 8);
    } else {
      if (data.length < 2) return null;
      return data[1];
    }
  }
}
