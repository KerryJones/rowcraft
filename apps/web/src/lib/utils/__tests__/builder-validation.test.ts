import { describe, it, expect } from 'vitest';
import { validateWorkout } from '../builder-validation';
import type { WorkoutSegment } from '../../types';

function makeSegment(overrides: Partial<WorkoutSegment> = {}): WorkoutSegment {
  return {
    duration_type: 'time',
    duration_value: 300,
    target_intensity: 90,
    target_stroke_rate: null,
    target_hr_zone: null,
    messages: null,
    ...overrides,
  };
}

describe('validateWorkout', () => {
  describe('title validation', () => {
    it('requires a non-empty title', () => {
      const result = validateWorkout('', [makeSegment()]);
      expect(result.valid).toBe(false);
      expect(result.error).toBe('Title is required');
    });

    it('rejects whitespace-only title', () => {
      const result = validateWorkout('   ', [makeSegment()]);
      expect(result.valid).toBe(false);
      expect(result.error).toBe('Title is required');
    });

    it('accepts a title with content', () => {
      const result = validateWorkout('My Workout', [makeSegment()]);
      expect(result.valid).toBe(true);
    });
  });

  describe('segment validation', () => {
    it('requires at least one segment', () => {
      const result = validateWorkout('My Workout', []);
      expect(result.valid).toBe(false);
      expect(result.error).toBe('Add at least one segment');
    });

    it('accepts a single segment', () => {
      const result = validateWorkout('My Workout', [makeSegment()]);
      expect(result.valid).toBe(true);
      expect(result.error).toBeNull();
    });

    it('accepts multiple segments', () => {
      const result = validateWorkout('My Workout', [
        makeSegment({ target_intensity: 60 }),
        makeSegment({ target_intensity: 95 }),
        makeSegment({ target_intensity: null }),
        makeSegment({ target_intensity: 70 }),
      ]);
      expect(result.valid).toBe(true);
    });
  });

  describe('valid workout', () => {
    it('returns valid: true and error: null for a complete workout', () => {
      const result = validateWorkout('5x5 Intervals', [makeSegment()]);
      expect(result.valid).toBe(true);
      expect(result.error).toBeNull();
    });

    it('trims title before validation', () => {
      const result = validateWorkout('  My Workout  ', [makeSegment()]);
      expect(result.valid).toBe(true);
    });
  });
});
