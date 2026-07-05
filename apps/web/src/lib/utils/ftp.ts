import type { HrZone, HrZoneName, ZoneSystem } from '../types';
import { DEFAULT_FTP_WATTS } from '../types';

/**
 * Convert watts to pace in tenths of a second per 500m.
 * C2 formula: watts = 2.80 / (pace_seconds / 500)^3
 * Inverse: pace_seconds = (2.80 / watts)^(1/3) * 500
 */
export function wattsToPaceTenths(watts: number): number {
	if (watts <= 0) return 0;
	const paceSeconds = Math.pow(2.80 / watts, 1 / 3) * 500;
	return Math.round(paceSeconds * 10);
}

/**
 * Convert pace in tenths of a second per 500m to watts.
 * C2 formula: watts = 2.80 / (pace_seconds / 500)^3
 */
export function paceTenthsToWatts(tenths: number): number {
	if (tenths <= 0) return 0;
	const paceSeconds = tenths / 10;
	return Math.round(2.80 / Math.pow(paceSeconds / 500, 3));
}

/**
 * Format watts as a string, e.g., "185W"
 */
export function formatWatts(watts: number): string {
	return `${Math.round(watts)}W`;
}

/**
 * Zone boundaries for the unified 5-zone model.
 * Mirrors packages/shared/hr-zones.json (the single source of truth) — kept
 * as a literal here so the web bundle never imports outside the app root;
 * __tests__/hr-zone-boundaries.test.ts fails CI if the two drift.
 */
export const HR_ZONE_BOUNDARIES = [55, 75, 85, 92, 97] as const;

/**
 * Unified HR zones — boundaries shared by both standard and rowing systems.
 * Zone boundaries: 55 / 75 / 85 / 92 / 97 / 100 (%HRR or %HRmax fallback).
 * Below 55% is "Recovery" (standard) or "Below UT2" (rowing).
 */
export const HR_ZONES: HrZone[] = [
	{
		name: 'aerobic',
		label: 'Aerobic',
		shortLabel: 'Z1',
		rowingLabel: 'Base Aerobic',
		rowingShortLabel: 'UT2',
		minPct: HR_ZONE_BOUNDARIES[0],
		maxPct: HR_ZONE_BOUNDARIES[1],
	},
	{
		name: 'tempo',
		label: 'Tempo',
		shortLabel: 'Z2',
		rowingLabel: 'Aerobic Power',
		rowingShortLabel: 'UT1',
		minPct: HR_ZONE_BOUNDARIES[1],
		maxPct: HR_ZONE_BOUNDARIES[2],
	},
	{
		name: 'threshold',
		label: 'Threshold',
		shortLabel: 'Z3',
		rowingLabel: 'Threshold',
		rowingShortLabel: 'AT',
		minPct: HR_ZONE_BOUNDARIES[2],
		maxPct: HR_ZONE_BOUNDARIES[3],
	},
	{
		name: 'vo2max',
		label: 'VO2max',
		shortLabel: 'Z4',
		rowingLabel: 'VO2max',
		rowingShortLabel: 'TR',
		minPct: HR_ZONE_BOUNDARIES[3],
		maxPct: HR_ZONE_BOUNDARIES[4],
	},
	{
		name: 'max',
		label: 'Max',
		shortLabel: 'Z5',
		rowingLabel: 'Anaerobic',
		rowingShortLabel: 'AN',
		minPct: HR_ZONE_BOUNDARIES[4],
		maxPct: 100,
	},
];

/**
 * Convert a percentage (HRR or HRmax) to BPM.
 * When restingHr is provided, uses Karvonen/HRR formula:
 *   bpm = (maxHr - restingHr) * pct/100 + restingHr
 * Otherwise uses simple %HRmax.
 */
export function pctToBpm(
	pct: number,
	maxHr: number,
	restingHr?: number | null
): number {
	if (restingHr != null && maxHr > restingHr) {
		return Math.round(((maxHr - restingHr) * pct) / 100 + restingHr);
	}
	return Math.round((maxHr * pct) / 100);
}

/**
 * Get the BPM range for a given HR zone based on max heart rate and
 * optional resting heart rate (for HRR/Karvonen calculation).
 */
export function getHrZoneBpm(
	maxHr: number,
	zoneName: HrZoneName,
	restingHr?: number | null
): { min: number; max: number } {
	const zone = HR_ZONES.find((z) => z.name === zoneName);
	if (!zone) return { min: 0, max: 0 };
	return {
		min: pctToBpm(zone.minPct, maxHr, restingHr),
		max: pctToBpm(zone.maxPct, maxHr, restingHr),
	};
}

/**
 * Get a human-readable label for a HR zone.
 */
export function getHrZoneLabel(
	zoneName: HrZoneName,
	zoneSystem: ZoneSystem = 'rowing'
): string {
	const zone = HR_ZONES.find((z) => z.name === zoneName);
	if (!zone) return zoneName;
	return zoneSystem === 'rowing' ? zone.rowingLabel : zone.label;
}

/**
 * Get the short label (Z1/UT2 etc.) for a HR zone.
 */
export function getHrZoneShortLabel(
	zoneName: HrZoneName,
	zoneSystem: ZoneSystem = 'rowing'
): string {
	const zone = HR_ZONES.find((z) => z.name === zoneName);
	if (!zone) return zoneName;
	return zoneSystem === 'rowing' ? zone.rowingShortLabel : zone.shortLabel;
}

/**
 * Get the HR zone index (1-5) for a zone name.
 */
export function getHrZoneNumber(zoneName: HrZoneName): number {
	const index = HR_ZONES.findIndex((z) => z.name === zoneName);
	return index >= 0 ? index + 1 : 0;
}

/**
 * Get the HR zone name from a zone number (1-5).
 */
export function getHrZoneFromNumber(zoneNumber: number): HrZoneName | null {
	if (zoneNumber < 1 || zoneNumber > HR_ZONES.length) return null;
	return HR_ZONES[zoneNumber - 1].name;
}

/**
 * Resolve an intensity percentage to watts given an FTP.
 */
export function intensityToWatts(intensityPct: number, ftpWatts: number): number {
	return Math.round((ftpWatts * intensityPct) / 100);
}

/**
 * Resolve an intensity percentage to pace tenths given an FTP.
 */
export function intensityToPaceTenths(intensityPct: number, ftpWatts: number): number {
	return wattsToPaceTenths(intensityToWatts(intensityPct, ftpWatts));
}

/**
 * Resolve an intensity percentage to target pace in tenths per 500m.
 * Higher intensity % -> more watts -> faster pace (lower number).
 */
export function resolveIntensityToPace(
	intensityPct: number,
	ftpWatts: number
): number {
	return intensityToPaceTenths(intensityPct, ftpWatts);
}

/**
 * Get the user's effective FTP, falling back to default if not set.
 */
export function getEffectiveFtp(ftpWatts: number | null): number {
	return ftpWatts ?? DEFAULT_FTP_WATTS;
}

/**
 * Derive HR zone (1-5) from intensity % of FTP.
 * Boundaries: 55 / 75 / 85 / 92 / 97.
 * Returns null for intensities below 55% or null/undefined input.
 */
export function intensityToHrZone(intensityPct: number | null | undefined): number | null {
	if (intensityPct == null) return null;
	if (intensityPct < HR_ZONE_BOUNDARIES[0]) return null;
	for (let zone = 1; zone < HR_ZONE_BOUNDARIES.length; zone++) {
		if (intensityPct < HR_ZONE_BOUNDARIES[zone]) return zone;
	}
	return HR_ZONE_BOUNDARIES.length; // max / AN
}
