import { describe, it, expect } from 'vitest';
import { estimateHrZone, timeInZone, timeInZoneBySegment } from '../hr-zones';
import type { WorkoutTimeSample } from '../../types';

function sample(
	t: number,
	hr: number | undefined,
	si = 0,
): WorkoutTimeSample {
	return { t, d: 0, p: 0, spm: 0, si, hr };
}

describe('estimateHrZone', () => {
	it('returns 0 when bpm or maxHr is non-positive', () => {
		expect(estimateHrZone(0, 200)).toBe(0);
		expect(estimateHrZone(150, 0)).toBe(0);
	});

	it('uses %HRmax when restingHr is not supplied', () => {
		// 50% of 200 = 100 → below 55% → zone 0
		expect(estimateHrZone(100, 200)).toBe(0);
		// 80% of 200 = 160 → zone 2 (75-85%)
		expect(estimateHrZone(160, 200)).toBe(2);
		// 100% of 200 = 200 → zone 5
		expect(estimateHrZone(200, 200)).toBe(5);
	});

	it('uses %HRR (Karvonen) when restingHr is supplied', () => {
		// max=200, rest=50, (140-50)/(200-50)=60% → zone 1 (55-75)
		expect(estimateHrZone(140, 200, 50)).toBe(1);
		// (170-50)/(200-50)=80% → zone 2
		expect(estimateHrZone(170, 200, 50)).toBe(2);
	});

	it('falls back to %HRmax when restingHr >= maxHr', () => {
		// Defensive: nonsense profile shouldn't divide-by-zero.
		// 75% of 200 is exactly on the Z1/Z2 boundary; code uses `< 75` → Z2.
		expect(estimateHrZone(150, 200, 200)).toBe(2);
	});
});

describe('timeInZone', () => {
	it('returns empty when no HR samples', () => {
		expect(timeInZone([], 50, 200)).toEqual({});
		expect(timeInZone([sample(0, undefined)], 50, 200)).toEqual({});
	});

	it('weights each sample by gap to next sample', () => {
		// hr=170, max=200 → zone 3 (85%). Three samples 2s apart.
		const samples = [
			sample(0, 170),
			sample(2000, 170),
			sample(4000, 170),
		];
		const result = timeInZone(samples, null, 200);
		// First two contribute 2s each; last uses median of [2,2] = 2s
		expect(result).toEqual({ 3: 6 });
	});

	it('drops zone-0 (below 55%) samples', () => {
		const samples = [
			sample(0, 50), // 25% → zone 0
			sample(2000, 170), // 85% → zone 3
		];
		const result = timeInZone(samples, null, 200);
		expect(result[0]).toBeUndefined();
		expect(result[3]).toBeGreaterThan(0);
	});

	it('handles a single sample with default 1s weight', () => {
		const result = timeInZone([sample(0, 170)], null, 200);
		expect(result).toEqual({ 3: 1 });
	});

	it('accumulates time across multiple zones', () => {
		const samples = [
			sample(0, 140), // 70% → zone 1
			sample(1000, 170), // 85% → zone 3
		];
		const result = timeInZone(samples, null, 200);
		expect(result[1]).toBeGreaterThan(0);
		expect(result[3]).toBeGreaterThan(0);
	});
});

describe('timeInZoneBySegment', () => {
	it('groups samples by segment index and computes time-in-zone per group', () => {
		const samples = [
			sample(0, 170, 0),
			sample(1000, 170, 0),
			sample(2000, 140, 1),
			sample(3000, 140, 1),
		];
		const result = timeInZoneBySegment(samples, null, 200);
		expect(Object.keys(result)).toEqual(expect.arrayContaining(['0', '1']));
		expect(result[0][3]).toBeGreaterThan(0); // segment 0 in zone 3
		expect(result[1][1]).toBeGreaterThan(0); // segment 1 in zone 1
	});

	it('returns empty object for empty input', () => {
		expect(timeInZoneBySegment([], 50, 200)).toEqual({});
	});
});
