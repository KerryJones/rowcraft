import { describe, it, expect } from 'vitest';
import { getSegmentDisplayColor } from '../segment-color';
import type { WorkoutSegment } from '../../types';

function makeSegment(overrides: Partial<WorkoutSegment> = {}): WorkoutSegment {
  return {
    duration_type: 'time',
    duration_value: 300,
    target_intensity: null,
    target_watts: null,
    target_stroke_rate: null,
    target_hr_zone: null,
    messages: null,
    ...overrides,
  };
}

describe('getSegmentDisplayColor', () => {
  describe('HR zone colors', () => {
    it('returns Z1 color (green) for zone 1', () => {
      expect(getSegmentDisplayColor(makeSegment({ target_hr_zone: 1 }))).toBe('#66BB6A');
    });

    it('returns Z2 color (blue) for zone 2', () => {
      expect(getSegmentDisplayColor(makeSegment({ target_hr_zone: 2 }))).toBe('#29B6F6');
    });

    it('returns Z3 color (amber) for zone 3', () => {
      expect(getSegmentDisplayColor(makeSegment({ target_hr_zone: 3 }))).toBe('#FFB300');
    });

    it('returns Z4 color (orange) for zone 4', () => {
      expect(getSegmentDisplayColor(makeSegment({ target_hr_zone: 4 }))).toBe('#FF7043');
    });

    it('returns Z5 color (red) for zone 5', () => {
      expect(getSegmentDisplayColor(makeSegment({ target_hr_zone: 5 }))).toBe('#EF5350');
    });
  });

  describe('fallback to gray', () => {
    it('returns gray when target_hr_zone is null', () => {
      expect(getSegmentDisplayColor(makeSegment({ target_hr_zone: null }))).toBe('#6b7280');
    });

    it('returns gray for rest segment (no intensity, no stroke rate)', () => {
      expect(getSegmentDisplayColor(makeSegment({
        target_intensity: null,
        target_stroke_rate: null,
        target_hr_zone: null,
      }))).toBe('#6b7280');
    });

    it('returns gray for stroke-rate-only segment (no intensity)', () => {
      expect(getSegmentDisplayColor(makeSegment({
        target_intensity: null,
        target_stroke_rate: 20,
        target_hr_zone: null,
      }))).toBe('#6b7280');
    });
  });
});
