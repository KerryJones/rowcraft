import type { WorkoutSegment } from '@/lib/types';

const HR_ZONE_COLORS: Record<number, string> = {
  1: '#66BB6A', // recovery — green
  2: '#29B6F6', // aerobic — light blue
  3: '#FFB300', // tempo — amber
  4: '#FF7043', // threshold — deep orange
  5: '#EF5350', // VO2 max — red
};

export const SEGMENT_REST_COLOR = '#6b7280'; // gray-500

/** Color for a segment based on its stored HR zone. No zone = gray. */
export function getSegmentDisplayColor(segment: WorkoutSegment): string {
  if (segment.target_hr_zone != null && HR_ZONE_COLORS[segment.target_hr_zone]) {
    return HR_ZONE_COLORS[segment.target_hr_zone];
  }
  return SEGMENT_REST_COLOR;
}

export { HR_ZONE_COLORS };
