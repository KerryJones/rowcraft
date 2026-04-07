import type { WorkoutSegment } from '@/lib/types';

export interface BuilderValidationResult {
  valid: boolean;
  error: string | null;
}

export function validateWorkout(
  title: string,
  segments: WorkoutSegment[],
): BuilderValidationResult {
  if (!title.trim()) {
    return { valid: false, error: 'Title is required' };
  }
  if (segments.length < 1) {
    return { valid: false, error: 'Add at least one segment' };
  }
  return { valid: true, error: null };
}
