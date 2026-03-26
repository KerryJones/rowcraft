import 'dart:typed_data';

/// CSAFE frame builder for programming the Concept2 PM5.
///
/// CSAFE (Communication Specification for Fitness Equipment) is the
/// protocol used to send commands to the PM5 via BLE. Commands are
/// wrapped in frames with start/stop flags and a checksum.
///
/// Reference: Concept2 CSAFE Specification
class CsafeCommands {
  CsafeCommands._();

  // Frame flags
  static const int frameStartFlag = 0xF1;
  static const int frameStopFlag = 0xF2;
  static const int frameStuffFlag = 0xF3;

  // Standard CSAFE commands
  static const int cmdGoReady = 0x85;
  static const int cmdGoIdle = 0x86;
  static const int cmdGoFinished = 0x8A;
  static const int cmdReset = 0x81;
  static const int cmdGetStatus = 0x80;

  // PM-specific extended commands (wrapped in CSAFE_SETUSERCFG1_CMD)
  static const int cmdSetUserCfg1 = 0x1A;
  static const int pmCmdSetWorkoutType = 0x01;
  static const int pmCmdSetWorkoutDuration = 0x03;
  static const int pmCmdSetSplitDuration = 0x05;
  static const int pmCmdSetRestDuration = 0x04;
  static const int pmCmdSetIntervalCount = 0x18;

  // Workout types for PM
  static const int workoutTypeFreeRow = 0x00;
  static const int workoutTypeSingleDistance = 0x01;
  static const int workoutTypeSingleTime = 0x02;
  static const int workoutTypeTimedInterval = 0x03;
  static const int workoutTypeDistanceInterval = 0x04;
  static const int workoutTypeVariable = 0x05;

  /// Build a CSAFE frame around the given command bytes.
  ///
  /// Format: [START_FLAG] [cmd bytes...] [CHECKSUM] [STOP_FLAG]
  /// Checksum is XOR of all command bytes.
  static Uint8List buildFrame(List<int> commands) {
    // Calculate checksum (XOR of all command bytes)
    int checksum = 0;
    for (final byte in commands) {
      checksum ^= byte;
    }

    // Build frame with byte stuffing
    final frame = <int>[frameStartFlag];
    for (final byte in commands) {
      _addWithStuffing(frame, byte);
    }
    _addWithStuffing(frame, checksum);
    frame.add(frameStopFlag);

    return Uint8List.fromList(frame);
  }

  /// Add a byte with CSAFE byte stuffing.
  ///
  /// Per CSAFE spec: reserved bytes are escaped by emitting the stuff flag
  /// followed by the byte XOR'd with 0x20.
  static void _addWithStuffing(List<int> frame, int byte) {
    if (byte == frameStartFlag ||
        byte == frameStopFlag ||
        byte == frameStuffFlag) {
      frame.add(frameStuffFlag);
      frame.add(byte ^ 0x20);
    } else {
      frame.add(byte);
    }
  }

  /// Command: Put PM5 into Ready state.
  static Uint8List goReady() => buildFrame([cmdGoReady]);

  /// Command: Put PM5 into Idle state.
  static Uint8List goIdle() => buildFrame([cmdGoIdle]);

  /// Command: Put PM5 into Finished state.
  static Uint8List goFinished() => buildFrame([cmdGoFinished]);

  /// Command: Reset the PM5.
  static Uint8List reset() => buildFrame([cmdReset]);

  /// Command: Get PM5 status.
  static Uint8List getStatus() => buildFrame([cmdGetStatus]);

  /// Command: Program a single distance workout.
  ///
  /// [distanceMeters] — target distance in meters.
  static Uint8List programSingleDistance(int distanceMeters) {
    return buildFrame([
      cmdSetUserCfg1,
      // Payload length
      0x06,
      pmCmdSetWorkoutType,
      0x01, // data length
      workoutTypeSingleDistance,
      pmCmdSetWorkoutDuration,
      0x02, // data length (2 bytes for distance)
      distanceMeters & 0xFF,
      (distanceMeters >> 8) & 0xFF,
    ]);
  }

  /// Command: Program a single time workout.
  ///
  /// [seconds] — target time in seconds.
  static Uint8List programSingleTime(int seconds) {
    // PM5 expects time as hours:minutes:seconds
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    return buildFrame([
      cmdSetUserCfg1,
      0x07,
      pmCmdSetWorkoutType,
      0x01,
      workoutTypeSingleTime,
      pmCmdSetWorkoutDuration,
      0x03, // 3 bytes for H:M:S
      hours,
      minutes,
      secs,
    ]);
  }

  /// Command: Program an interval workout.
  ///
  /// [intervals] — number of intervals.
  /// [workDistance] — work distance per interval in meters.
  /// [restSeconds] — rest time between intervals.
  static Uint8List programDistanceIntervals({
    required int intervals,
    required int workDistance,
    required int restSeconds,
  }) {
    final restMinutes = restSeconds ~/ 60;
    final restSecs = restSeconds % 60;

    return buildFrame([
      cmdSetUserCfg1,
      0x0C,
      pmCmdSetWorkoutType,
      0x01,
      workoutTypeDistanceInterval,
      pmCmdSetIntervalCount,
      0x01,
      intervals,
      pmCmdSetSplitDuration,
      0x02,
      workDistance & 0xFF,
      (workDistance >> 8) & 0xFF,
      pmCmdSetRestDuration,
      0x02,
      restMinutes,
      restSecs,
    ]);
  }

  /// Command: Program a timed interval workout.
  ///
  /// [intervals] — number of intervals.
  /// [workSeconds] — work time per interval.
  /// [restSeconds] — rest time between intervals.
  static Uint8List programTimedIntervals({
    required int intervals,
    required int workSeconds,
    required int restSeconds,
  }) {
    final workMinutes = workSeconds ~/ 60;
    final workSecs = workSeconds % 60;
    final restMinutes = restSeconds ~/ 60;
    final restSecs = restSeconds % 60;

    return buildFrame([
      cmdSetUserCfg1,
      0x0C,
      pmCmdSetWorkoutType,
      0x01,
      workoutTypeTimedInterval,
      pmCmdSetIntervalCount,
      0x01,
      intervals,
      pmCmdSetSplitDuration,
      0x02,
      workMinutes,
      workSecs,
      pmCmdSetRestDuration,
      0x02,
      restMinutes,
      restSecs,
    ]);
  }
}
