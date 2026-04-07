import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/workout_segment.dart';

/// Color for a segment based on its stored HR zone.
/// No zone (rest / SPM-only) = gray.
Color segmentDisplayColor(WorkoutSegment seg) {
  final zone = seg.targetHrZone;
  if (zone == null) return RowCraftTheme.segmentRest;
  return switch (zone) {
    1 => RowCraftTheme.hrZone1,
    2 => RowCraftTheme.hrZone2,
    3 => RowCraftTheme.hrZone3,
    4 => RowCraftTheme.hrZone4,
    5 => RowCraftTheme.hrZone5,
    _ => RowCraftTheme.segmentRest,
  };
}
