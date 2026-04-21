import { describe, it, expect } from 'vitest';
import { normalizeWorkoutSegments } from '../types';
import type { WorkoutSegment } from '../types';

describe('normalizeWorkoutSegments', () => {
	it('ensures messages is null when missing', () => {
		const segments: any[] = [
			{
				duration_type: 'time',
				duration_value: 300,
				target_intensity: 95,
				target_stroke_rate: null,
				target_hr_zone: null,
				// messages field missing entirely
			},
		];

		const result = normalizeWorkoutSegments(segments);
		expect(result[0].messages).toBeNull();
	});

	it('passes through segments with intensity targets unchanged', () => {
		const segments: WorkoutSegment[] = [
			{
				duration_type: 'time',
				duration_value: 300,
				target_intensity: 90,
				target_watts: null,
				target_stroke_rate: null,
				target_hr_zone: null,
				messages: null,
			},
			{
				duration_type: 'time',
				duration_value: 60,
				target_intensity: null,
				target_watts: null,
				target_stroke_rate: null,
				target_hr_zone: null,
				messages: null,
			},
		];

		const result = normalizeWorkoutSegments(segments);
		expect(result[0].target_intensity).toBe(90);
		expect(result[1].target_intensity).toBeNull();
	});
});
