import { describe, it, expect } from 'vitest';
import {
	computeTotalTime,
	computeTotalDistance,
	computeSegmentCount,
	groupSegments,
	expandSegments,
	computeIntensity,
	computeCumulativeMinutes,
} from '../workout';
import type { WorkoutSegment } from '../../types';

function makeSegment(overrides: Partial<WorkoutSegment> = {}): WorkoutSegment {
	return {
		type: 'work',
		duration_type: 'time',
		duration_value: 300,
		target_split: null,
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
			makeSegment({ duration_type: 'time', duration_value: 60, type: 'rest' }),
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
		const work = makeSegment({ type: 'work', duration_type: 'distance', duration_value: 500, target_split: { pace: 1100 } });
		const rest = makeSegment({ type: 'rest', duration_type: 'time', duration_value: 60 });
		// 10 x 500m work + 10 x 1:00 rest (alternating in source, but grouped when consecutive)
		const segments = [work, work, work, rest, rest, rest];
		const groups = groupSegments(segments);
		expect(groups).toHaveLength(2);
		expect(groups[0].count).toBe(3);
		expect(groups[0].segment.type).toBe('work');
		expect(groups[1].count).toBe(3);
		expect(groups[1].segment.type).toBe('rest');
	});

	it('does not group segments with different paces', () => {
		const fast = makeSegment({ target_split: { pace: 1000 } });
		const slow = makeSegment({ target_split: { pace: 1400 } });
		const groups = groupSegments([fast, slow]);
		expect(groups).toHaveLength(2);
		expect(groups[0].count).toBe(1);
		expect(groups[1].count).toBe(1);
	});

	it('does not group segments with different types', () => {
		const work = makeSegment({ type: 'work' });
		const rest = makeSegment({ type: 'rest' });
		const groups = groupSegments([work, rest, work]);
		expect(groups).toHaveLength(3);
	});

	it('handles all-identical segments', () => {
		const seg = makeSegment({ type: 'work', duration_value: 300 });
		const groups = groupSegments([seg, seg, seg, seg, seg]);
		expect(groups).toHaveLength(1);
		expect(groups[0].count).toBe(5);
	});

	it('counts multiple identical consecutive segments', () => {
		const work = makeSegment({ type: 'work', duration_value: 500, duration_type: 'distance', target_split: { pace: 1100 } });
		const groups = groupSegments([work, work, work, work, work, work, work, work, work, work]);
		expect(groups).toHaveLength(1);
		expect(groups[0].count).toBe(10);
	});
});

describe('expandSegments', () => {
	it('returns single segments unchanged', () => {
		const seg = makeSegment({ type: 'work' });
		const expanded = expandSegments([seg]);
		expect(expanded).toHaveLength(1);
		expect(expanded[0].type).toBe('work');
	});

	it('passes through all individual segments', () => {
		const work = makeSegment({ type: 'work', duration_type: 'distance', duration_value: 500 });
		const rest = makeSegment({ type: 'rest', duration_type: 'time', duration_value: 60 });
		const expanded = expandSegments([work, rest, work, rest, work, rest]);
		expect(expanded).toHaveLength(6);
		expect(expanded.map(s => s.type)).toEqual(['work', 'rest', 'work', 'rest', 'work', 'rest']);
	});

	it('handles warmup + intervals + cooldown', () => {
		const warmup = makeSegment({ type: 'warmup' });
		const work = makeSegment({ type: 'work' });
		const rest = makeSegment({ type: 'rest' });
		const cooldown = makeSegment({ type: 'cooldown' });
		const segments = [warmup, work, rest, work, rest, work, rest, work, rest, work, rest, cooldown];
		const expanded = expandSegments(segments);
		expect(expanded).toHaveLength(12);
		expect(expanded[0].type).toBe('warmup');
		expect(expanded[1].type).toBe('work');
		expect(expanded[2].type).toBe('rest');
		expect(expanded[11].type).toBe('cooldown');
	});

	it('preserves segment order', () => {
		const work = makeSegment({ type: 'work' });
		const rest = makeSegment({ type: 'rest' });
		const cooldown = makeSegment({ type: 'cooldown' });
		const expanded = expandSegments([work, rest, cooldown, work, rest, cooldown, work, rest, cooldown]);
		expect(expanded).toHaveLength(9);
		expect(expanded.map(s => s.type)).toEqual([
			'work', 'rest', 'cooldown',
			'work', 'rest', 'cooldown',
			'work', 'rest', 'cooldown',
		]);
	});
});

describe('computeIntensity', () => {
	it('returns null when no segments have pace targets', () => {
		const segments = [makeSegment({ target_split: null })];
		expect(computeIntensity(segments)).toBeNull();
	});

	it('returns 1.0 for workout at exactly reference pace (2:00/500m)', () => {
		const segments = [makeSegment({ target_split: { pace: 1200 } })];
		expect(computeIntensity(segments)).toBe(1.0);
	});

	it('returns > 1.0 for faster-than-reference workout', () => {
		const segments = [makeSegment({ target_split: { pace: 1000 } })];
		const intensity = computeIntensity(segments)!;
		expect(intensity).toBeGreaterThan(1.0);
	});

	it('returns < 1.0 for slower-than-reference workout', () => {
		const segments = [makeSegment({ target_split: { pace: 1500 } })];
		const intensity = computeIntensity(segments)!;
		expect(intensity).toBeLessThan(1.0);
	});

	it('weights by duration', () => {
		// 10 min easy + 1 min hard → should be closer to easy intensity
		const easy = makeSegment({ duration_value: 600, target_split: { pace: 1500 } });
		const hard = makeSegment({ duration_value: 60, target_split: { pace: 900 } });
		const mixed = computeIntensity([easy, hard])!;
		const easyOnly = computeIntensity([easy])!;
		expect(mixed).toBeGreaterThan(easyOnly);
		expect(mixed).toBeLessThan(1.0); // still mostly easy
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
});
