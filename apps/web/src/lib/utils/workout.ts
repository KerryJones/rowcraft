import type { WorkoutSegment } from '@/lib/types';

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
 * Two segments are "identical" if same type, duration_type, duration_value, and target_split pace.
 */
export interface GroupedSegment {
	segment: WorkoutSegment;
	count: number;
}

export function groupSegments(segments: WorkoutSegment[]): GroupedSegment[] {
	if (segments.length === 0) return [];

	const groups: GroupedSegment[] = [];
	let current = segments[0];
	let count = 1;

	for (let i = 1; i < segments.length; i++) {
		const seg = segments[i];
		const samePace =
			current.target_split?.pace === seg.target_split?.pace &&
			(current.target_split === null) === (seg.target_split === null);

		if (
			seg.type === current.type &&
			seg.duration_type === current.duration_type &&
			seg.duration_value === current.duration_value &&
			samePace
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
 * Weighted average of segment pace against a 2:00/500m (1200 tenths) reference.
 * Higher = harder. Time-weighted by segment duration.
 * Returns null if no segments have pace targets.
 */
export function computeIntensity(segments: WorkoutSegment[]): number | null {
	const referencePace = 1200; // 2:00/500m in tenths
	let totalWeight = 0;
	let weightedSum = 0;

	for (const seg of segments) {
		if (!seg.target_split) continue;
		const duration = seg.duration_value;
		// Invert: faster pace (lower number) = higher intensity
		const intensity = referencePace / seg.target_split.pace;
		weightedSum += intensity * duration;
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
			// Estimate time from pace, or assume 2:00/500m
			const pacePerMeter = seg.target_split
				? (seg.target_split.pace / 10) / 500
				: 0.24; // 2:00/500m = 0.24 sec/m
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
