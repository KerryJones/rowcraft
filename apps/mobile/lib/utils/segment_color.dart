import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/workout_segment.dart';
import 'hr_zones.dart';

/// Color for a segment based on its stored HR zone.
/// No zone (rest / s/m-only) = gray.
Color segmentDisplayColor(WorkoutSegment seg) {
  final zone = seg.targetHrZone;
  if (zone == null) return RowCraftTheme.segmentRest;
  return zoneColor(zone);
}
