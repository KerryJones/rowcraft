import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Zone system preference — stored in profiles.zone_system.
enum ZoneSystem {
  standard,
  rowing;

  static ZoneSystem fromString(String? value) {
    if (value == 'standard') return ZoneSystem.standard;
    return ZoneSystem.rowing; // default
  }

  String toJsonString() => name;
}

/// Definition for a single HR zone.
class HrZoneDefinition {
  final int number; // 1-5
  final String label;
  final String shortLabel;
  final double minPct; // 0-100 (%HRR or %HRmax)
  final double maxPct;
  final Color color;

  const HrZoneDefinition({
    required this.number,
    required this.label,
    required this.shortLabel,
    required this.minPct,
    required this.maxPct,
    required this.color,
  });
}

/// Standard zones (Z1-Z5). Below Z1 is "Recovery".
const standardZones = [
  HrZoneDefinition(
    number: 1,
    label: 'Aerobic',
    shortLabel: 'Z1',
    minPct: 55,
    maxPct: 75,
    color: RowCraftTheme.hrZone1,
  ),
  HrZoneDefinition(
    number: 2,
    label: 'Tempo',
    shortLabel: 'Z2',
    minPct: 75,
    maxPct: 85,
    color: RowCraftTheme.hrZone2,
  ),
  HrZoneDefinition(
    number: 3,
    label: 'Threshold',
    shortLabel: 'Z3',
    minPct: 85,
    maxPct: 92,
    color: RowCraftTheme.hrZone3,
  ),
  HrZoneDefinition(
    number: 4,
    label: 'VO2max',
    shortLabel: 'Z4',
    minPct: 92,
    maxPct: 97,
    color: RowCraftTheme.hrZone4,
  ),
  HrZoneDefinition(
    number: 5,
    label: 'Max',
    shortLabel: 'Z5',
    minPct: 97,
    maxPct: 100,
    color: RowCraftTheme.hrZone5,
  ),
];

/// Rowing zones. Below UT2 (<55%) is unlabeled / "Below UT2".
const rowingZones = [
  HrZoneDefinition(
    number: 1,
    label: 'Base Aerobic',
    shortLabel: 'UT2',
    minPct: 55,
    maxPct: 75,
    color: RowCraftTheme.hrZone1,
  ),
  HrZoneDefinition(
    number: 2,
    label: 'Aerobic Power',
    shortLabel: 'UT1',
    minPct: 75,
    maxPct: 85,
    color: RowCraftTheme.hrZone2,
  ),
  HrZoneDefinition(
    number: 3,
    label: 'Threshold',
    shortLabel: 'AT',
    minPct: 85,
    maxPct: 92,
    color: RowCraftTheme.hrZone3,
  ),
  HrZoneDefinition(
    number: 4,
    label: 'VO2max',
    shortLabel: 'TR',
    minPct: 92,
    maxPct: 97,
    color: RowCraftTheme.hrZone4,
  ),
  HrZoneDefinition(
    number: 5,
    label: 'Anaerobic',
    shortLabel: 'AN',
    minPct: 97,
    maxPct: 100,
    color: RowCraftTheme.hrZone5,
  ),
];

/// Get zone definitions for a given system.
List<HrZoneDefinition> zonesForSystem(ZoneSystem system) =>
    system == ZoneSystem.rowing ? rowingZones : standardZones;

/// Convert a percentage (of HRR or HRmax) to a BPM value.
///
/// When [restingHr] is provided, uses Karvonen/HRR formula:
///   bpm = (maxHr - restingHr) * pct/100 + restingHr
///
/// Otherwise uses simple %HRmax:
///   bpm = maxHr * pct/100
int pctToBpm(double pct, int maxHr, {int? restingHr}) {
  if (restingHr != null && maxHr > restingHr) {
    return ((maxHr - restingHr) * pct / 100 + restingHr).round();
  }
  return (maxHr * pct / 100).round();
}

/// Get the BPM range for a zone (1-5).
({int min, int max}) zoneBpmRange(
  int zone,
  int maxHr, {
  int? restingHr,
  ZoneSystem system = ZoneSystem.rowing,
}) {
  final zones = zonesForSystem(system);
  if (zone < 1 || zone > zones.length) {
    // Zone 0 / below zone
    return (
      min: 0,
      max: pctToBpm(zones.first.minPct, maxHr, restingHr: restingHr),
    );
  }
  final def = zones[zone - 1];
  return (
    min: pctToBpm(def.minPct, maxHr, restingHr: restingHr),
    max: pctToBpm(def.maxPct, maxHr, restingHr: restingHr),
  );
}

/// Estimate HR zone (0-5) from BPM.
/// Zone 0 = below zone 1 (recovery / below UT2).
/// Uses HRR (Karvonen) when restingHr is provided, %HRmax otherwise.
///
/// Zone boundaries: 55 / 75 / 85 / 92 / 97 / 100
/// These are the same for both standard and rowing systems.
int estimateHrZone(int bpm, int maxHr, {int? restingHr}) {
  if (maxHr <= 0 || bpm <= 0) return 0;

  // Convert BPM to percentage (HRR or HRmax)
  double pct;
  if (restingHr != null && maxHr > restingHr) {
    pct = (bpm - restingHr) / (maxHr - restingHr) * 100;
  } else {
    pct = bpm / maxHr * 100;
  }

  if (pct < 55) return 0;
  if (pct < 75) return 1;
  if (pct < 85) return 2;
  if (pct < 92) return 3;
  if (pct < 97) return 4;
  return 5;
}

/// Get zone color for a zone number (0-5).
/// Zone 0 (below zones) uses the first zone's color (green).
Color zoneColor(int zone) {
  if (zone == 0) return RowCraftTheme.hrZone1;
  return switch (zone) {
    1 => RowCraftTheme.hrZone1,
    2 => RowCraftTheme.hrZone2,
    3 => RowCraftTheme.hrZone3,
    4 => RowCraftTheme.hrZone4,
    5 => RowCraftTheme.hrZone5,
    _ => RowCraftTheme.subtleGrey,
  };
}

/// Get zone display info: short name, full label, color.
({String name, String label, Color color}) zoneDisplayInfo(
  int zone,
  ZoneSystem system,
) {
  if (zone == 0) {
    final label = system == ZoneSystem.rowing ? 'Below UT2' : 'Recovery';
    return (name: label, label: label, color: RowCraftTheme.hrZone1);
  }
  final zones = zonesForSystem(system);
  if (zone >= 1 && zone <= zones.length) {
    final def = zones[zone - 1];
    return (name: def.shortLabel, label: def.label, color: def.color);
  }
  return (name: 'Z?', label: '', color: RowCraftTheme.subtleGrey);
}

