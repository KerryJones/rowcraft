import { describe, it, expect } from 'vitest';
import { getSegmentDisplayColor } from '../segment-color';
import type { WorkoutSegment } from '../../types';

function makeSegment(overrides: Partial<WorkoutSegment> = {}): WorkoutSegment {
  return {
    type: 'work',
    duration_type: 'time',
    duration_value: 300,
    target_intensity: null,
    target_stroke_rate: null,
    target_hr_zone: null,
    messages: null,
    ...overrides,
  };
}

describe('getSegmentDisplayColor', () => {
  describe('type-based colors', () => {
    it('returns blue for work segments', () => {
      expect(getSegmentDisplayColor(makeSegment({ type: 'work' }))).toBe('#3b82f6');
    });

    it('returns gray for rest segments', () => {
      expect(getSegmentDisplayColor(makeSegment({ type: 'rest' }))).toBe('#6b7280');
    });

    it('returns green for warmup segments', () => {
      expect(getSegmentDisplayColor(makeSegment({ type: 'warmup' }))).toBe('#22c55e');
    });

    it('returns yellow for cooldown segments', () => {
      expect(getSegmentDisplayColor(makeSegment({ type: 'cooldown' }))).toBe('#eab308');
    });
  });

  describe('HR zone override', () => {
    it('returns HR zone color when zone is set on work segment', () => {
      expect(getSegmentDisplayColor(makeSegment({ type: 'work', target_hr_zone: 1 }))).toBe('#66BB6A');
      expect(getSegmentDisplayColor(makeSegment({ type: 'work', target_hr_zone: 2 }))).toBe('#29B6F6');
      expect(getSegmentDisplayColor(makeSegment({ type: 'work', target_hr_zone: 3 }))).toBe('#FFB300');
      expect(getSegmentDisplayColor(makeSegment({ type: 'work', target_hr_zone: 4 }))).toBe('#FF7043');
      expect(getSegmentDisplayColor(makeSegment({ type: 'work', target_hr_zone: 5 }))).toBe('#EF5350');
    });

    it('returns HR zone color on warmup and cooldown segments', () => {
      expect(getSegmentDisplayColor(makeSegment({ type: 'warmup', target_hr_zone: 2 }))).toBe('#29B6F6');
      expect(getSegmentDisplayColor(makeSegment({ type: 'cooldown', target_hr_zone: 1 }))).toBe('#66BB6A');
    });

    it('ignores HR zone on rest segments (always gray)', () => {
      expect(getSegmentDisplayColor(makeSegment({ type: 'rest', target_hr_zone: 3 }))).toBe('#6b7280');
      expect(getSegmentDisplayColor(makeSegment({ type: 'rest', target_hr_zone: 5 }))).toBe('#6b7280');
    });

    it('falls back to type color for unrecognized HR zone', () => {
      expect(getSegmentDisplayColor(makeSegment({ type: 'work', target_hr_zone: 99 }))).toBe('#3b82f6');
      expect(getSegmentDisplayColor(makeSegment({ type: 'work', target_hr_zone: 0 }))).toBe('#3b82f6');
    });

    it('falls back to type color when HR zone is null', () => {
      expect(getSegmentDisplayColor(makeSegment({ type: 'work', target_hr_zone: null }))).toBe('#3b82f6');
    });
  });
});
