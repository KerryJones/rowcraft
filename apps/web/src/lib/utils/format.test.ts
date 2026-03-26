import { describe, it, expect } from 'vitest';
import {
	formatPace,
	formatDuration,
	formatTimeTenths,
	formatDistance,
	formatWorkoutType,
	formatSegmentType,
	parsePace
} from './format';

describe('formatPace', () => {
	it('formats 1200 tenths as 2:00.0', () => {
		expect(formatPace(1200)).toBe('2:00.0');
	});

	it('formats 1055 tenths as 1:45.5', () => {
		expect(formatPace(1055)).toBe('1:45.5');
	});

	it('formats 0 as 0:00.0', () => {
		expect(formatPace(0)).toBe('0:00.0');
	});
});

describe('formatDuration', () => {
	it('formats 1800 seconds as 30:00', () => {
		expect(formatDuration(1800)).toBe('30:00');
	});

	it('formats 3661 seconds as 1:01:01', () => {
		expect(formatDuration(3661)).toBe('1:01:01');
	});

	it('formats 59 seconds as 0:59', () => {
		expect(formatDuration(59)).toBe('0:59');
	});
});

describe('formatTimeTenths', () => {
	it('formats 12000 tenths as 20:00.0', () => {
		expect(formatTimeTenths(12000)).toBe('20:00.0');
	});

	it('formats 0 as 0:00.0', () => {
		expect(formatTimeTenths(0)).toBe('0:00.0');
	});
});

describe('formatDistance', () => {
	it('formats 2000 meters as 2,000m', () => {
		expect(formatDistance(2000)).toBe('2,000m');
	});

	it('formats 500 meters as 500m', () => {
		expect(formatDistance(500)).toBe('500m');
	});
});

describe('formatWorkoutType', () => {
	it('formats intervals', () => {
		expect(formatWorkoutType('intervals')).toBe('Intervals');
	});

	it('formats single_distance as Distance', () => {
		expect(formatWorkoutType('single_distance')).toBe('Distance');
	});

	it('formats single_time as Time', () => {
		expect(formatWorkoutType('single_time')).toBe('Time');
	});

	it('formats variable_intervals as Variable', () => {
		expect(formatWorkoutType('variable_intervals')).toBe('Variable');
	});

	it('titlecases unknown types', () => {
		expect(formatWorkoutType('unknown')).toBe('Unknown');
	});
});

describe('formatSegmentType', () => {
	it('formats work as Work', () => {
		expect(formatSegmentType('work')).toBe('Work');
	});

	it('formats warmup as Warm Up', () => {
		expect(formatSegmentType('warmup')).toBe('Warm Up');
	});
});

describe('parsePace', () => {
	it('parses 2:00.0 to 1200', () => {
		expect(parsePace('2:00.0')).toBe(1200);
	});

	it('parses 1:45.5 to 1055', () => {
		expect(parsePace('1:45.5')).toBe(1055);
	});

	it('returns null for invalid input', () => {
		expect(parsePace('invalid')).toBeNull();
	});

	it('returns null for invalid seconds >= 60', () => {
		expect(parsePace('2:60.0')).toBeNull();
	});
});
