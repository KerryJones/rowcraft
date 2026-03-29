import { describe, it, expect } from 'vitest';
import { computeTotalTime, computeTotalDistance, computeSegmentCount } from '../workout';
import type { WorkoutSegment } from '../../types';

function makeSegment(overrides: Partial<WorkoutSegment> = {}): WorkoutSegment {
	return {
		type: 'work',
		duration_type: 'time',
		duration_value: 300,
		target_split: null,
		target_stroke_rate: null,
		target_hr_zone: null,
		repeat: 1,
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

	it('accounts for repeats', () => {
		const segments = [
			makeSegment({ duration_type: 'time', duration_value: 300, repeat: 3 }),
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

	it('accounts for repeats', () => {
		const segments = [
			makeSegment({ duration_type: 'distance', duration_value: 500, repeat: 4 }),
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

	it('accounts for repeats', () => {
		const segments = [
			makeSegment({ repeat: 3 }),
			makeSegment({ repeat: 2 }),
		];
		expect(computeSegmentCount(segments)).toBe(5);
	});

	it('returns 0 for empty array', () => {
		expect(computeSegmentCount([])).toBe(0);
	});

	it('treats repeat=0 or undefined as 1', () => {
		const segments = [
			makeSegment({ repeat: 0 }),
		];
		// repeat || 1 means 0 becomes 1
		expect(computeSegmentCount(segments)).toBe(1);
	});
});
