import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/workout_segment.dart';

/// Color by HR zone when available, rest always gray, fallback to type color.
/// Used for graph bars, segment headers, up-next previews — anywhere a segment
/// needs a display color.
Color segmentDisplayColor(WorkoutSegment seg) {
  if (seg.type == SegmentType.rest) return RowCraftTheme.segmentRest;
  if (seg.targetHrZone != null) {
    return switch (seg.targetHrZone!) {
      1 => RowCraftTheme.hrZone1,
      2 => RowCraftTheme.hrZone2,
      3 => RowCraftTheme.hrZone3,
      4 => RowCraftTheme.hrZone4,
      5 => RowCraftTheme.hrZone5,
      _ => _segmentTypeColor(seg.type),
    };
  }
  return _segmentTypeColor(seg.type);
}

Color _segmentTypeColor(SegmentType type) {
  return switch (type) {
    SegmentType.work => RowCraftTheme.segmentWork,
    SegmentType.rest => RowCraftTheme.segmentRest,
    SegmentType.warmup => RowCraftTheme.segmentWarmup,
    SegmentType.cooldown => RowCraftTheme.segmentCooldown,
  };
}
