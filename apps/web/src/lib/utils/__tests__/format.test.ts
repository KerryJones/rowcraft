import { describe, it, expect } from 'vitest';
import {
	formatPace,
	formatDuration,
	formatTimeTenths,
	formatDistance,
	formatWorkoutType,
	formatSegmentType,
	formatDifficulty,
	formatSegmentDuration,
	parsePace,
} from '../format';
import type { WorkoutSegment } from '../../types';

describe('formatPace', () => {
	it('formats 2:00 pace (1200 tenths)', () => {
		expect(formatPace(1200)).toBe('2:00');
	});

	it('formats 2:14 pace (1340 tenths)', () => {
		expect(formatPace(1340)).toBe('2:14');
	});

	it('formats 1:45 pace (1050 tenths)', () => {
		expect(formatPace(1050)).toBe('1:45');
	});

	it('formats sub-minute paces', () => {
		expect(formatPace(550)).toBe('0:55');
	});

	it('formats with zero seconds correctly padded', () => {
		expect(formatPace(1200)).toBe('2:00');
		expect(formatPace(1800)).toBe('3:00');
	});

	it('handles edge case of 0', () => {
		expect(formatPace(0)).toBe('0:00');
	});
});

describe('parsePace', () => {
	it('parses 2:00 to 1200 tenths', () => {
		expect(parsePace('2:00')).toBe(1200);
	});

	it('parses 2:14 to 1340 tenths', () => {
		expect(parsePace('2:14')).toBe(1340);
	});

	it('parses 1:45 to 1050 tenths', () => {
		expect(parsePace('1:45')).toBe(1050);
	});

	it('returns null for invalid input', () => {
		expect(parsePace('abc')).toBeNull();
		expect(parsePace('')).toBeNull();
		expect(parsePace('2:60')).toBeNull();
		expect(parsePace('2:99')).toBeNull();
	});

	it('handles single-digit seconds', () => {
		expect(parsePace('2:5')).toBe(1250);
	});

	it('roundtrips with formatPace', () => {
		const paces = [1200, 1340, 1050, 900, 1800];
		for (const pace of paces) {
			expect(parsePace(formatPace(pace))).toBe(pace);
		}
	});
});

describe('formatDuration', () => {
	it('formats seconds under an hour', () => {
		expect(formatDuration(1800)).toBe('30:00');
		expect(formatDuration(300)).toBe('5:00');
		expect(formatDuration(90)).toBe('1:30');
	});

	it('formats seconds over an hour', () => {
		expect(formatDuration(3661)).toBe('1:01:01');
		expect(formatDuration(7200)).toBe('2:00:00');
	});

	it('handles zero', () => {
		expect(formatDuration(0)).toBe('0:00');
	});

	it('pads minutes and seconds in hour format', () => {
		expect(formatDuration(3601)).toBe('1:00:01');
		expect(formatDuration(3660)).toBe('1:01:00');
	});
});

describe('formatTimeTenths', () => {
	it('formats tenths of seconds', () => {
		expect(formatTimeTenths(12000)).toBe('20:00.0');
	});

	it('includes tenths digit', () => {
		expect(formatTimeTenths(12005)).toBe('20:00.5');
	});

	it('handles hour+ durations', () => {
		expect(formatTimeTenths(36015)).toBe('1:00:01.5');
	});
});

describe('formatDistance', () => {
	it('formats with comma separators', () => {
		expect(formatDistance(2000)).toBe('2,000m');
		expect(formatDistance(10000)).toBe('10,000m');
	});

	it('handles small distances', () => {
		expect(formatDistance(500)).toBe('500m');
	});
});

describe('formatWorkoutType', () => {
	it('formats known types', () => {
		expect(formatWorkoutType('single_distance')).toBe('Distance');
		expect(formatWorkoutType('single_time')).toBe('Time');
		expect(formatWorkoutType('intervals')).toBe('Intervals');
		expect(formatWorkoutType('variable_intervals')).toBe('Variable');
	});

	it('formats unknown types with title case', () => {
		expect(formatWorkoutType('some_new_type')).toBe('Some New Type');
	});
});

describe('formatSegmentType', () => {
	it('formats known types', () => {
		expect(formatSegmentType('work')).toBe('Work');
		expect(formatSegmentType('rest')).toBe('Rest');
		expect(formatSegmentType('warmup')).toBe('Warm Up');
		expect(formatSegmentType('cooldown')).toBe('Cool Down');
	});
});

describe('formatDifficulty', () => {
	it('formats known difficulties', () => {
		expect(formatDifficulty('beginner')).toBe('Beginner');
		expect(formatDifficulty('intermediate')).toBe('Intermediate');
		expect(formatDifficulty('advanced')).toBe('Advanced');
	});
});

describe('formatSegmentDuration', () => {
	const makeSegment = (overrides: Partial<WorkoutSegment>): WorkoutSegment => ({
		type: 'work',
		duration_type: 'time',
		duration_value: 300,
		target_intensity: null,
		target_stroke_rate: null,
		target_hr_zone: null,
		messages: null,
		...overrides,
	});

	it('formats time-based segments', () => {
		expect(formatSegmentDuration(makeSegment({ duration_type: 'time', duration_value: 300 }))).toBe('5:00');
	});

	it('formats distance-based segments', () => {
		expect(formatSegmentDuration(makeSegment({ duration_type: 'distance', duration_value: 2000 }))).toBe('2,000m');
	});

	it('formats calorie-based segments', () => {
		expect(formatSegmentDuration(makeSegment({ duration_type: 'calories', duration_value: 150 }))).toBe('150cal');
	});
});
