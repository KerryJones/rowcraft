import { describe, it, expect } from 'vitest';
import {
	computeTotalTime,
	computeTotalDistance,
	computeSegmentCount,
	groupSegments,
	expandSegments,
	computeIntensity,
	computeCumulativeMinutes,
	estimateTotalSeconds,
	inferWorkoutType,
} from '../workout';
import type { WorkoutSegment } from '../../types';

function makeSegment(overrides: Partial<WorkoutSegment> = {}): WorkoutSegment {
	return {
		duration_type: 'time',
		duration_value: 300,
		target_intensity: null,
		target_stroke_rate: null,
		target_hr_zone: null,
		messages: null,
		...overrides,
	};
}

describe('computeTotalTime', () => {
	it('sums time-based segments', () => {
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 300 }),
			makeSegment({ duration_type: 'time', duration_value: 60 }),
			makeSegment({ duration_type: 'time', duration_value: 300 }),
		];
		expect(computeTotalTime(segments)).toBe(660);
	});

	it('sums multiple identical segments', () => {
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 300 }),
			makeSegment({ duration_type: 'time', duration_value: 300 }),
			makeSegment({ duration_type: 'time', duration_value: 300 }),
		];
		expect(computeTotalTime(segments)).toBe(900);
	});

	it('ignores distance-based segments', () => {
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 300 }),
			makeSegment({ duration_type: 'distance', duration_value: 2000 }),
		];
		expect(computeTotalTime(segments)).toBe(300);
	});

	it('returns null for no time-based segments', () => {
		const segments = [
			makeSegment({ duration_type: 'distance', duration_value: 2000 }),
		];
		expect(computeTotalTime(segments)).toBeNull();
	});

	it('returns null for empty array', () => {
		expect(computeTotalTime([])).toBeNull();
	});
});

describe('computeTotalDistance', () => {
	it('sums distance-based segments', () => {
		const segments = [
			makeSegment({ duration_type: 'distance', duration_value: 2000 }),
			makeSegment({ duration_type: 'distance', duration_value: 1000 }),
		];
		expect(computeTotalDistance(segments)).toBe(3000);
	});

	it('sums multiple identical segments', () => {
		const segments = [
			makeSegment({ duration_type: 'distance', duration_value: 500 }),
			makeSegment({ duration_type: 'distance', duration_value: 500 }),
			makeSegment({ duration_type: 'distance', duration_value: 500 }),
			makeSegment({ duration_type: 'distance', duration_value: 500 }),
		];
		expect(computeTotalDistance(segments)).toBe(2000);
	});

	it('returns null for no distance-based segments', () => {
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 300 }),
		];
		expect(computeTotalDistance(segments)).toBeNull();
	});
});

describe('computeSegmentCount', () => {
	it('counts segments', () => {
		const segments = [makeSegment(), makeSegment(), makeSegment()];
		expect(computeSegmentCount(segments)).toBe(3);
	});

	it('counts individual segments', () => {
		const segments = [
			makeSegment(),
			makeSegment(),
			makeSegment(),
			makeSegment(),
			makeSegment(),
		];
		expect(computeSegmentCount(segments)).toBe(5);
	});

	it('returns 0 for empty array', () => {
		expect(computeSegmentCount([])).toBe(0);
	});
});

describe('groupSegments', () => {
	it('returns empty array for empty input', () => {
		expect(groupSegments([])).toEqual([]);
	});

	it('single segment returns count 1', () => {
		const segments = [makeSegment()];
		const groups = groupSegments(segments);
		expect(groups).toHaveLength(1);
		expect(groups[0].count).toBe(1);
	});

	it('groups consecutive identical segments', () => {
		const active = makeSegment({ duration_type: 'distance', duration_value: 500, target_intensity: 95 });
		const rest = makeSegment({ duration_type: 'time', duration_value: 60, target_intensity: null });
		const segments = [active, active, active, rest, rest, rest];
		const groups = groupSegments(segments);
		expect(groups).toHaveLength(2);
		expect(groups[0].count).toBe(3);
		expect(groups[0].segment.target_intensity).toBe(95);
		expect(groups[1].count).toBe(3);
		expect(groups[1].segment.target_intensity).toBeNull();
	});

	it('does not group segments with different intensities', () => {
		const hard = makeSegment({ target_intensity: 95 });
		const easy = makeSegment({ target_intensity: 65 });
		const groups = groupSegments([hard, easy]);
		expect(groups).toHaveLength(2);
		expect(groups[0].count).toBe(1);
		expect(groups[1].count).toBe(1);
	});

	it('does not group segments with different durations', () => {
		const short = makeSegment({ target_intensity: 90, duration_value: 300 });
		const long = makeSegment({ target_intensity: 90, duration_value: 600 });
		const groups = groupSegments([short, long, short]);
		expect(groups).toHaveLength(3);
	});

	it('handles all-identical segments', () => {
		const seg = makeSegment({ target_intensity: 90, duration_value: 300 });
		const groups = groupSegments([seg, seg, seg, seg, seg]);
		expect(groups).toHaveLength(1);
		expect(groups[0].count).toBe(5);
	});

	it('counts multiple identical consecutive segments', () => {
		const work = makeSegment({ duration_value: 500, duration_type: 'distance', target_intensity: 95 });
		const groups = groupSegments([work, work, work, work, work, work, work, work, work, work]);
		expect(groups).toHaveLength(1);
		expect(groups[0].count).toBe(10);
	});
});

describe('expandSegments', () => {
	it('returns single segments unchanged', () => {
		const seg = makeSegment({ target_intensity: 90 });
		const expanded = expandSegments([seg]);
		expect(expanded).toHaveLength(1);
		expect(expanded[0].target_intensity).toBe(90);
	});

	it('passes through all individual segments', () => {
		const active = makeSegment({ duration_type: 'distance', duration_value: 500, target_intensity: 95 });
		const rest = makeSegment({ duration_type: 'time', duration_value: 60, target_intensity: null });
		const expanded = expandSegments([active, rest, active, rest, active, rest]);
		expect(expanded).toHaveLength(6);
	});

	it('preserves segment order', () => {
		const s1 = makeSegment({ target_intensity: 60 });
		const s2 = makeSegment({ target_intensity: 95 });
		const s3 = makeSegment({ target_intensity: null });
		const expanded = expandSegments([s1, s2, s3, s1, s2, s3]);
		expect(expanded).toHaveLength(6);
		expect(expanded[0].target_intensity).toBe(60);
		expect(expanded[1].target_intensity).toBe(95);
		expect(expanded[2].target_intensity).toBeNull();
	});
});

describe('computeIntensity', () => {
	it('returns null when no segments have intensity targets', () => {
		const segments = [makeSegment({ target_intensity: null })];
		expect(computeIntensity(segments)).toBeNull();
	});

	it('returns 1.0 for workout at exactly 100% FTP', () => {
		const segments = [makeSegment({ target_intensity: 100 })];
		expect(computeIntensity(segments)).toBe(1.0);
	});

	it('returns > 1.0 for above-FTP workout', () => {
		const segments = [makeSegment({ target_intensity: 115 })];
		const intensity = computeIntensity(segments)!;
		expect(intensity).toBeGreaterThan(1.0);
	});

	it('returns < 1.0 for below-FTP workout', () => {
		const segments = [makeSegment({ target_intensity: 65 })];
		const intensity = computeIntensity(segments)!;
		expect(intensity).toBeLessThan(1.0);
	});

	it('weights by duration', () => {
		// 10 min easy + 1 min hard → should be closer to easy intensity
		const easy = makeSegment({ duration_value: 600, target_intensity: 65 });
		const hard = makeSegment({ duration_value: 60, target_intensity: 115 });
		const mixed = computeIntensity([easy, hard])!;
		const easyOnly = computeIntensity([easy])!;
		expect(mixed).toBeGreaterThan(easyOnly);
		expect(mixed).toBeLessThan(1.0); // still mostly easy
	});
});

describe('inferWorkoutType', () => {
	it('returns single_time for empty segments', () => {
		expect(inferWorkoutType([])).toBe('single_time');
	});

	it('returns single_time for all rest segments', () => {
		const segments = [makeSegment({ target_intensity: null, target_stroke_rate: null })];
		expect(inferWorkoutType(segments)).toBe('single_time');
	});

	it('returns single_distance for one distance segment', () => {
		const segments = [
			makeSegment({ duration_type: 'distance', duration_value: 2000, target_intensity: 80 }),
		];
		expect(inferWorkoutType(segments)).toBe('single_distance');
	});

	it('returns single_time for one time segment', () => {
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 1200, target_intensity: 75 }),
		];
		expect(inferWorkoutType(segments)).toBe('single_time');
	});

	it('returns single_distance for one distance segment with rest', () => {
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 60 }), // rest (no targets)
			makeSegment({ duration_type: 'distance', duration_value: 5000, target_intensity: 70 }),
			makeSegment({ duration_type: 'time', duration_value: 60 }), // rest
		];
		expect(inferWorkoutType(segments)).toBe('single_distance');
	});

	it('returns intervals for identical active segments', () => {
		const work = makeSegment({ duration_type: 'distance', duration_value: 500, target_intensity: 95 });
		const rest = makeSegment({ duration_type: 'time', duration_value: 60 });
		expect(inferWorkoutType([work, rest, work, rest, work])).toBe('intervals');
	});

	it('returns variable_intervals for mixed active segments', () => {
		const hard = makeSegment({ duration_type: 'time', duration_value: 120, target_intensity: 100 });
		const easy = makeSegment({ duration_type: 'time', duration_value: 300, target_intensity: 65 });
		expect(inferWorkoutType([hard, easy, hard, easy])).toBe('variable_intervals');
	});

	it('treats stroke-rate-only segments as active', () => {
		const spmOnly = makeSegment({ target_intensity: null, target_stroke_rate: 24 });
		expect(inferWorkoutType([spmOnly])).toBe('single_time');
	});

	it('counts stroke-rate-only segments toward interval detection', () => {
		const spm = makeSegment({ target_stroke_rate: 24, duration_value: 300 });
		expect(inferWorkoutType([spm, spm, spm])).toBe('intervals');
	});
});

describe('computeCumulativeMinutes', () => {
	it('starts at 0', () => {
		const markers = computeCumulativeMinutes([makeSegment({ duration_value: 300 })]);
		expect(markers[0].minute).toBe(0);
	});

	it('computes correct end time for time-based segments', () => {
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 300 }), // 5 min
			makeSegment({ duration_type: 'time', duration_value: 60 }),  // 1 min
		];
		const markers = computeCumulativeMinutes(segments);
		expect(markers).toHaveLength(3); // start + 2 segment ends
		expect(markers[1].minute).toBe(5);
		expect(markers[2].minute).toBe(6);
	});

	it('returns one more marker than segments', () => {
		const segments = [makeSegment(), makeSegment(), makeSegment()];
		expect(computeCumulativeMinutes(segments)).toHaveLength(4);
	});

	it('uses provided FTP for distance segment estimation', () => {
		const segments = [
			makeSegment({ duration_type: 'distance', duration_value: 1000, target_intensity: 100 }),
		];
		const markersDefault = computeCumulativeMinutes(segments, 150);
		const markersHighFtp = computeCumulativeMinutes(segments, 250);
		// Higher FTP = faster pace = shorter duration
		expect(markersHighFtp[1].minute).toBeLessThan(markersDefault[1].minute);
	});
});

describe('estimateTotalSeconds', () => {
	it('returns total seconds for time-based segments', () => {
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 300 }),
			makeSegment({ duration_type: 'time', duration_value: 120 }),
		];
		expect(estimateTotalSeconds(segments)).toBe(420);
	});

	it('includes estimated time for distance segments in mixed workouts', () => {
		// Bug regression: mixed time+distance workouts must include both
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 300 }),     // 5 min
			makeSegment({ duration_type: 'distance', duration_value: 3000, target_intensity: 100 }), // ~13 min at 150W
			makeSegment({ duration_type: 'time', duration_value: 300 }),     // 5 min
		];
		const secs = estimateTotalSeconds(segments);
		// Must be > 600 (the 10 min from time-only segments)
		expect(secs).toBeGreaterThan(600);
		// Should be around 23-24 min total
		expect(secs).toBeGreaterThan(1200);
		expect(secs).toBeLessThan(1800);
	});

	it('uses provided FTP for estimation', () => {
		const segments = [
			makeSegment({ duration_type: 'distance', duration_value: 2000, target_intensity: 100 }),
		];
		const secsDefault = estimateTotalSeconds(segments, 150);
		const secsHighFtp = estimateTotalSeconds(segments, 250);
		// Higher FTP = faster pace = less time
		expect(secsHighFtp).toBeLessThan(secsDefault);
	});
});
