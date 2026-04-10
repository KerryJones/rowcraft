import type { WorkoutSegment, WorkoutType } from '@/lib/types';
import { DEFAULT_FTP_WATTS, isRestSegment } from '../types';
import { resolveIntensityToPace } from './ftp';

/**
 * Compute total time in seconds for all time-based segments (accounting for repeats).
 * Returns null if there are no time-based segments.
 */
export function computeTotalTime(segments: WorkoutSegment[]): number | null {
	let total = 0;
	let hasTimeBased = false;

	for (const seg of segments) {
		if (seg.duration_type === 'time') {
			total += seg.duration_value;
			hasTimeBased = true;
		}
	}

	return hasTimeBased ? total : null;
}

/**
 * Compute total distance in meters for all distance-based segments (accounting for repeats).
 * Returns null if no distance-based segments exist.
 */
export function computeTotalDistance(segments: WorkoutSegment[]): number | null {
	let total = 0;
	let hasDistanceBased = false;

	for (const seg of segments) {
		if (seg.duration_type === 'distance') {
			total += seg.duration_value;
			hasDistanceBased = true;
		}
	}

	return hasDistanceBased ? total : null;
}

/**
 * Compute total expanded segment count (accounting for repeats).
 */
export function computeSegmentCount(segments: WorkoutSegment[]): number {
	return segments.length;
}

/**
 * Return segments as-is (segments are already individual).
 * Kept for API compatibility.
 */
export function expandSegments(segments: WorkoutSegment[]): WorkoutSegment[] {
	return segments;
}

/**
 * Group consecutive identical segments for display.
 * Two segments are "identical" if same type, duration_type, duration_value, and target_intensity.
 */
export interface GroupedSegment {
	segment: WorkoutSegment;
	count: number;
}

function sameIntensity(a: WorkoutSegment, b: WorkoutSegment): boolean {
	return a.target_intensity === b.target_intensity;
}

export function groupSegments(segments: WorkoutSegment[]): GroupedSegment[] {
	if (segments.length === 0) return [];

	const groups: GroupedSegment[] = [];
	let current = segments[0];
	let count = 1;

	for (let i = 1; i < segments.length; i++) {
		const seg = segments[i];

		if (
			seg.duration_type === current.duration_type &&
			seg.duration_value === current.duration_value &&
			sameIntensity(current, seg) &&
			seg.target_stroke_rate === current.target_stroke_rate
		) {
			count += 1;
		} else {
			groups.push({ segment: current, count });
			current = seg;
			count = 1;
		}
	}
	groups.push({ segment: current, count });

	return groups;
}

/**
 * Compute workout intensity score (0.00 - 1.00+).
 * Weighted average of segment intensity % against 100% FTP.
 * Higher = harder. Duration-weighted by segment duration.
 * Returns null if no segments have intensity targets.
 */
export function computeIntensity(segments: WorkoutSegment[]): number | null {
	let totalWeight = 0;
	let weightedSum = 0;

	for (const seg of segments) {
		if (seg.target_intensity == null) continue;
		const duration = seg.duration_value;
		weightedSum += (seg.target_intensity / 100) * duration;
		totalWeight += duration;
	}

	if (totalWeight === 0) return null;
	return Math.round((weightedSum / totalWeight) * 100) / 100;
}

/**
 * Compute cumulative minute markers for graph X-axis.
 * Returns array of { minute, label } for each segment boundary.
 * For distance-based segments, estimates time from pace (or uses 2:00/500m default).
 */
export interface MinuteMarker {
	minute: number;
	segmentIndex: number;
}

export function computeCumulativeMinutes(segments: WorkoutSegment[]): MinuteMarker[] {
	const markers: MinuteMarker[] = [{ minute: 0, segmentIndex: 0 }];
	let cumulativeSeconds = 0;

	for (let i = 0; i < segments.length; i++) {
		const seg = segments[i];
		let segSeconds: number;

		if (seg.duration_type === 'time') {
			segSeconds = seg.duration_value;
		} else if (seg.duration_type === 'distance') {
			// Estimate time from intensity-resolved pace, or assume 2:00/500m
			let pacePerMeter = 0.24; // 2:00/500m = 0.24 sec/m
			if (seg.target_intensity != null) {
				const pace = resolveIntensityToPace(seg.target_intensity, DEFAULT_FTP_WATTS);
				pacePerMeter = (pace / 10) / 500;
			}
			segSeconds = seg.duration_value * pacePerMeter;
		} else {
			// Calories — rough estimate: ~15 cal/min
			segSeconds = (seg.duration_value / 15) * 60;
		}

		cumulativeSeconds += segSeconds;
		markers.push({
			minute: Math.round(cumulativeSeconds / 60 * 10) / 10,
			segmentIndex: i + 1,
		});
	}

	return markers;
}

/**
 * Estimate total workout duration in minutes (including distance/calorie segments).
 */
export function estimateTotalMinutes(segments: WorkoutSegment[]): number {
	const markers = computeCumulativeMinutes(segments);
	return markers[markers.length - 1]?.minute ?? 0;
}

/**
 * Compute the dominant HR zone (duration-weighted).
 * Returns the zone number (1-5) with the most total duration, or null if no zones.
 */
export function computeDominantZone(segments: WorkoutSegment[]): number | null {
	const zoneDurations: Record<number, number> = {};

	for (const seg of segments) {
		if (seg.target_hr_zone == null) continue;
		zoneDurations[seg.target_hr_zone] = (zoneDurations[seg.target_hr_zone] ?? 0) + seg.duration_value;
	}

	let maxZone: number | null = null;
	let maxDuration = 0;
	for (const [zone, duration] of Object.entries(zoneDurations)) {
		if (duration > maxDuration) {
			maxDuration = duration;
			maxZone = Number(zone);
		}
	}

	return maxZone;
}

/**
 * Infer workout type from segment structure.
 * - 1 active segment + distance → single_distance
 * - 1 active segment + time → single_time
 * - Multiple identical active segments → intervals
 * - Otherwise → variable_intervals
 */
export function inferWorkoutType(segments: WorkoutSegment[]): WorkoutType {
	// For classification, treat a segment as rest if it's explicitly flagged
	// OR if it's a time-based segment with no active targets (the common
	// "60s recovery" pattern, saved without the explicit is_rest flag).
	// Distance segments without targets are still treated as active work
	// ("just row 5k") — rest is conventionally time-based.
	const isEffectivelyRest = (s: WorkoutSegment): boolean =>
		isRestSegment(s) ||
		(s.duration_type === 'time' &&
			s.target_intensity == null &&
			s.target_stroke_rate == null);
	const activeSegs = segments.filter((s) => !isEffectivelyRest(s));

	if (activeSegs.length === 0) return 'single_time';

	if (activeSegs.length === 1) {
		return activeSegs[0].duration_type === 'distance' ? 'single_distance' : 'single_time';
	}

	const allIdentical = activeSegs.every((s) =>
		s.duration_type === activeSegs[0].duration_type &&
		s.duration_value === activeSegs[0].duration_value &&
		s.target_intensity === activeSegs[0].target_intensity &&
		s.target_stroke_rate === activeSegs[0].target_stroke_rate
	);

	if (allIdentical) return 'intervals';

	return 'variable_intervals';
}
