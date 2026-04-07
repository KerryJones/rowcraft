import type { HrZone, HrZoneName } from '../types';
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
 * HR zones based on physiologically accurate defaults (Attia/Seiler research).
 * Z2 ceiling at 75% is the pre-lactate threshold — the key endurance zone.
 */
export const HR_ZONES: HrZone[] = [
	{ name: 'recovery', label: 'Recovery', minPct: 0, maxPct: 60 },
	{ name: 'aerobic', label: 'Aerobic', minPct: 60, maxPct: 75 },
	{ name: 'tempo', label: 'Tempo', minPct: 75, maxPct: 85 },
	{ name: 'threshold', label: 'Threshold', minPct: 85, maxPct: 92 },
	{ name: 'max', label: 'Max', minPct: 92, maxPct: 100 },
];

/**
 * Get the BPM range for a given HR zone based on max heart rate.
 */
export function getHrZoneBpm(
	maxHr: number,
	zoneName: HrZoneName
): { min: number; max: number } {
	const zone = HR_ZONES.find((z) => z.name === zoneName);
	if (!zone) return { min: 0, max: 0 };
	return {
		min: Math.round(maxHr * (zone.minPct / 100)),
		max: Math.round(maxHr * (zone.maxPct / 100)),
	};
}

/**
 * Get a human-readable label for a HR zone, e.g., "Aerobic"
 */
export function getHrZoneLabel(zoneName: HrZoneName): string {
	const zone = HR_ZONES.find((z) => z.name === zoneName);
	return zone?.label ?? zoneName;
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
 * Higher intensity % → more watts → faster pace (lower number).
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
 * Derive HR zone (1–5) from intensity % of FTP.
 * Boundaries match HR_ZONES thresholds above.
 * Returns null for null/undefined intensity.
 */
export function intensityToHrZone(intensityPct: number | null | undefined): number | null {
	if (intensityPct == null) return null;
	if (intensityPct < 60) return 1;   // recovery
	if (intensityPct < 75) return 2;   // aerobic
	if (intensityPct < 85) return 3;   // tempo
	if (intensityPct < 92) return 4;   // threshold
	return 5;                           // max / VO2max
}
