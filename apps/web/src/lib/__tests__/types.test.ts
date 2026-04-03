import { describe, it, expect } from 'vitest';
import { normalizeSplitTarget, normalizeWorkoutSegments } from '../types';
import type { WorkoutSegment } from '../types';

describe('normalizeSplitTarget', () => {
	it('passes through new format unchanged', () => {
		expect(normalizeSplitTarget({ pace: 1200 })).toEqual({ pace: 1200 });
	});

	it('converts legacy {min, max} format to single pace', () => {
		expect(normalizeSplitTarget({ min: 1100, max: 1300 } as any)).toEqual({ pace: 1200 });
	});

	it('returns null for null input', () => {
		expect(normalizeSplitTarget(null)).toBeNull();
	});

	it('rounds averaged legacy values', () => {
		const result = normalizeSplitTarget({ min: 1100, max: 1301 } as any);
		expect(result).toEqual({ pace: 1201 });
	});
});

describe('normalizeWorkoutSegments', () => {
	it('normalizes all segments in array', () => {
		const segments: any[] = [
			{
				type: 'work',
				duration_type: 'time',
				duration_value: 300,
				target_split: { min: 1100, max: 1300 },
				target_stroke_rate: null,
				target_hr_zone: null,
				},
			{
				type: 'rest',
				duration_type: 'time',
				duration_value: 60,
				target_split: null,
				target_stroke_rate: null,
				target_hr_zone: null,
				},
		];

		const result = normalizeWorkoutSegments(segments);

		expect(result[0].target_split).toEqual({ pace: 1200 });
		expect(result[1].target_split).toBeNull();
	});

	it('ensures messages is null when missing', () => {
		const segments: any[] = [
			{
				type: 'work',
				duration_type: 'time',
				duration_value: 300,
				target_split: { pace: 1200 },
				target_stroke_rate: null,
				target_hr_zone: null,
					// messages field missing entirely
			},
		];

		const result = normalizeWorkoutSegments(segments);
		expect(result[0].messages).toBeNull();
	});
});
