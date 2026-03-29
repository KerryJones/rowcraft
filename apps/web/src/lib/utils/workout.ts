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
			total += seg.duration_value * (seg.repeat || 1);
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
			total += seg.duration_value * (seg.repeat || 1);
			hasDistanceBased = true;
		}
	}

	return hasDistanceBased ? total : null;
}

/**
 * Compute total expanded segment count (accounting for repeats).
 */
export function computeSegmentCount(segments: WorkoutSegment[]): number {
	return segments.reduce((sum, seg) => sum + (seg.repeat || 1), 0);
}
