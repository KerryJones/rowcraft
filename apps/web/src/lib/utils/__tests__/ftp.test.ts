import { describe, it, expect } from 'vitest';
import {
	wattsToPaceTenths,
	paceTenthsToWatts,
	formatWatts,
	HR_ZONES,
	getHrZoneBpm,
	getHrZoneLabel,
	getHrZoneNumber,
	getHrZoneFromNumber,
	pctToBpm,
	intensityToHrZone,
} from '../ftp';

describe('wattsToPaceTenths', () => {
	it('converts 185W to approximately 2:00 pace', () => {
		const tenths = wattsToPaceTenths(185);
		// 185W should be close to 2:00 (1200 tenths)
		expect(tenths).toBeGreaterThan(1150);
		expect(tenths).toBeLessThan(1250);
	});

	it('higher watts = lower pace (faster)', () => {
		const fast = wattsToPaceTenths(250);
		const slow = wattsToPaceTenths(100);
		expect(fast).toBeLessThan(slow);
	});

	it('returns 0 for 0 watts', () => {
		expect(wattsToPaceTenths(0)).toBe(0);
	});

	it('returns 0 for negative watts', () => {
		expect(wattsToPaceTenths(-10)).toBe(0);
	});
});

describe('paceTenthsToWatts', () => {
	it('converts 2:00 pace (1200 tenths) to approximately 203W', () => {
		const watts = paceTenthsToWatts(1200);
		expect(watts).toBeGreaterThan(190);
		expect(watts).toBeLessThan(215);
	});

	it('faster pace = higher watts', () => {
		const fast = paceTenthsToWatts(900);  // 1:30
		const slow = paceTenthsToWatts(1500); // 2:30
		expect(fast).toBeGreaterThan(slow);
	});

	it('returns 0 for 0 tenths', () => {
		expect(paceTenthsToWatts(0)).toBe(0);
	});

	it('returns 0 for negative tenths', () => {
		expect(paceTenthsToWatts(-10)).toBe(0);
	});

	it('roundtrips with wattsToPaceTenths (within rounding tolerance)', () => {
		const originalWatts = 185;
		const tenths = wattsToPaceTenths(originalWatts);
		const backToWatts = paceTenthsToWatts(tenths);
		expect(Math.abs(backToWatts - originalWatts)).toBeLessThanOrEqual(2);
	});
});

describe('formatWatts', () => {
	it('formats whole watts', () => {
		expect(formatWatts(185)).toBe('185W');
	});

	it('rounds fractional watts', () => {
		expect(formatWatts(185.7)).toBe('186W');
	});
});

describe('HR_ZONES', () => {
	it('has 5 zones', () => {
		expect(HR_ZONES).toHaveLength(5);
	});

	it('zones are contiguous (no gaps)', () => {
		for (let i = 1; i < HR_ZONES.length; i++) {
			expect(HR_ZONES[i].minPct).toBe(HR_ZONES[i - 1].maxPct);
		}
	});

	it('starts at 55% and ends at 100%', () => {
		expect(HR_ZONES[0].minPct).toBe(55);
		expect(HR_ZONES[HR_ZONES.length - 1].maxPct).toBe(100);
	});

	it('zone names match expected values', () => {
		const names = HR_ZONES.map((z) => z.name);
		expect(names).toEqual(['aerobic', 'tempo', 'threshold', 'vo2max', 'max']);
	});
});

describe('getHrZoneBpm', () => {
	it('calculates BPM range for aerobic zone at 185 max HR (%HRmax fallback)', () => {
		const bpm = getHrZoneBpm(185, 'aerobic');
		expect(bpm.min).toBe(102); // 185 * 0.55
		expect(bpm.max).toBe(139); // 185 * 0.75 (rounded)
	});

	it('uses HRR/Karvonen when resting HR provided', () => {
		// Kerry's numbers: max=175, resting=50
		// UT2 ceiling = (175-50)*0.75 + 50 = 143.75 ≈ 144
		const bpm = getHrZoneBpm(175, 'aerobic', 50);
		expect(bpm.min).toBe(119); // (175-50)*0.55+50 = 118.75
		expect(bpm.max).toBe(144); // (175-50)*0.75+50 = 143.75
	});

	it('returns {0, 0} for unknown zone', () => {
		const bpm = getHrZoneBpm(185, 'nonexistent' as any);
		expect(bpm.min).toBe(0);
		expect(bpm.max).toBe(0);
	});
});

describe('pctToBpm', () => {
	it('uses %HRmax when no resting HR', () => {
		expect(pctToBpm(75, 175)).toBe(131); // 175 * 0.75
	});

	it('uses Karvonen when resting HR provided', () => {
		// (175-50)*0.75 + 50 = 143.75 ≈ 144
		expect(pctToBpm(75, 175, 50)).toBe(144);
	});
});

describe('getHrZoneLabel', () => {
	it('returns standard labels when system is standard', () => {
		expect(getHrZoneLabel('aerobic', 'standard')).toBe('Aerobic');
		expect(getHrZoneLabel('threshold', 'standard')).toBe('Threshold');
	});

	it('returns rowing labels when system is rowing', () => {
		expect(getHrZoneLabel('aerobic', 'rowing')).toBe('Base Aerobic');
		expect(getHrZoneLabel('threshold', 'rowing')).toBe('Threshold');
		expect(getHrZoneLabel('vo2max', 'rowing')).toBe('VO2max');
		expect(getHrZoneLabel('max', 'rowing')).toBe('Anaerobic');
	});
});

describe('getHrZoneNumber / getHrZoneFromNumber', () => {
	it('maps zone names to 1-indexed numbers', () => {
		expect(getHrZoneNumber('aerobic')).toBe(1);
		expect(getHrZoneNumber('tempo')).toBe(2);
		expect(getHrZoneNumber('max')).toBe(5);
	});

	it('maps numbers back to zone names', () => {
		expect(getHrZoneFromNumber(1)).toBe('aerobic');
		expect(getHrZoneFromNumber(2)).toBe('tempo');
		expect(getHrZoneFromNumber(5)).toBe('max');
	});

	it('returns null for out-of-range numbers', () => {
		expect(getHrZoneFromNumber(0)).toBeNull();
		expect(getHrZoneFromNumber(6)).toBeNull();
	});

	it('roundtrips correctly', () => {
		for (const zone of HR_ZONES) {
			const num = getHrZoneNumber(zone.name);
			expect(getHrZoneFromNumber(num)).toBe(zone.name);
		}
	});
});

describe('intensityToHrZone', () => {
	it('returns null for low intensity', () => {
		expect(intensityToHrZone(40)).toBeNull();
		expect(intensityToHrZone(54)).toBeNull();
	});

	it('maps intensity to correct zones', () => {
		expect(intensityToHrZone(60)).toBe(1);  // aerobic
		expect(intensityToHrZone(80)).toBe(2);  // tempo
		expect(intensityToHrZone(88)).toBe(3);  // threshold
		expect(intensityToHrZone(95)).toBe(4);  // VO2max
		expect(intensityToHrZone(99)).toBe(5);  // max
	});

	it('returns null for null/undefined', () => {
		expect(intensityToHrZone(null)).toBeNull();
		expect(intensityToHrZone(undefined)).toBeNull();
	});
});
