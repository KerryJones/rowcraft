import type { WorkoutSegment } from '$lib/types';

/**
 * Format a pace value (in tenths of a second per 500m) as m:ss
 * Displays whole seconds only — tenths are dropped for simplicity.
 * Example: 1340 -> "2:14", 1200 -> "2:00"
 */
export function formatPace(tenths: number): string {
	const totalSeconds = Math.floor(tenths / 10);
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;
	return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

/**
 * Format a duration in seconds as mm:ss or h:mm:ss
 * Example: 1800 -> "30:00", 3661 -> "1:01:01"
 */
export function formatDuration(seconds: number): string {
	const hours = Math.floor(seconds / 3600);
	const mins = Math.floor((seconds % 3600) / 60);
	const secs = seconds % 60;

	if (hours > 0) {
		return `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
	}
	return `${mins}:${secs.toString().padStart(2, '0')}`;
}

/**
 * Format tenths of seconds as mm:ss.t or h:mm:ss.t
 * Example: 12000 -> "20:00.0"
 */
export function formatTimeTenths(tenths: number): string {
	const totalSeconds = Math.floor(tenths / 10);
	const t = tenths % 10;
	const hours = Math.floor(totalSeconds / 3600);
	const mins = Math.floor((totalSeconds % 3600) / 60);
	const secs = totalSeconds % 60;

	if (hours > 0) {
		return `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}.${t}`;
	}
	return `${mins}:${secs.toString().padStart(2, '0')}.${t}`;
}

/**
 * Format a distance in meters with comma separators and unit
 * Example: 2000 -> "2,000m", 10000 -> "10,000m"
 */
export function formatDistance(meters: number): string {
	return `${meters.toLocaleString('en-US')}m`;
}

/**
 * Format a workout type enum value as a human-readable label
 */
export function formatWorkoutType(type: string): string {
	const labels: Record<string, string> = {
		single_distance: 'Distance',
		single_time: 'Time',
		intervals: 'Intervals',
		variable_intervals: 'Variable'
	};
	return labels[type] ?? type.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

/**
 * Format a segment type as a human-readable label
 */
export function formatSegmentType(type: string): string {
	const labels: Record<string, string> = {
		work: 'Work',
		rest: 'Rest',
		warmup: 'Warm Up',
		cooldown: 'Cool Down'
	};
	return labels[type] ?? type;
}

/**
 * Format a difficulty level as a human-readable label
 */
export function formatDifficulty(difficulty: string): string {
	const labels: Record<string, string> = {
		beginner: 'Beginner',
		intermediate: 'Intermediate',
		advanced: 'Advanced'
	};
	return labels[difficulty] ?? difficulty;
}

/**
 * Format a segment's duration as a human-readable string.
 * Consolidates the duplicated switch logic used in WorkoutGraph and detail page.
 */
export function formatSegmentDuration(seg: WorkoutSegment): string {
	switch (seg.duration_type) {
		case 'time':
			return formatDuration(seg.duration_value);
		case 'distance':
			return formatDistance(seg.duration_value);
		case 'calories':
			return `${seg.duration_value}cal`;
		default:
			return String(seg.duration_value);
	}
}

/**
 * Parse a pace string (m:ss) to tenths of a second per 500m.
 * Returns null if the string is invalid.
 * Example: "2:14" -> 1340
 */
export function parsePace(value: string): number | null {
	const match = value.match(/^(\d+):(\d{1,2})$/);
	if (!match) return null;
	const [, mins, secs] = match;
	const s = parseInt(secs);
	if (s >= 60) return null;
	return parseInt(mins) * 600 + s * 10;
}
