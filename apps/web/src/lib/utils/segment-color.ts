import type { WorkoutSegment, SegmentType } from '@/lib/types';

const SEGMENT_COLORS: Record<SegmentType, string> = {
  work: '#3b82f6',
  rest: '#6b7280',
  warmup: '#22c55e',
  cooldown: '#eab308',
};

const HR_ZONE_COLORS: Record<number, string> = {
  1: '#66BB6A', // recovery — green
  2: '#29B6F6', // endurance — light blue
  3: '#FFB300', // tempo — amber
  4: '#FF7043', // threshold — deep orange
  5: '#EF5350', // VO2 max — red
};

/** Color by HR zone when available, rest always gray, fallback to type color. */
export function getSegmentDisplayColor(segment: WorkoutSegment): string {
  if (segment.type === 'rest') return SEGMENT_COLORS.rest;
  if (segment.target_hr_zone != null && HR_ZONE_COLORS[segment.target_hr_zone]) {
    return HR_ZONE_COLORS[segment.target_hr_zone];
  }
  return SEGMENT_COLORS[segment.type];
}
