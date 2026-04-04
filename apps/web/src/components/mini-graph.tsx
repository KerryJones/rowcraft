import type { WorkoutSegment } from '@/lib/types';
import { getSegmentDisplayColor } from '@/lib/utils/segment-color';

/** Reference pace for scaling bar heights (very slow = 3:00/500m = 1800 tenths) */
const MAX_PACE = 1800;
/** Minimum bar height as a fraction of total height */
const MIN_HEIGHT_FRACTION = 0.15;

function getBarHeight(segment: WorkoutSegment, totalHeight: number): number {
  if (!segment.target_split) return totalHeight * MIN_HEIGHT_FRACTION;
  const pace = segment.target_split.pace;
  // Lower pace = more intense = taller bar
  const intensity = Math.max(0, Math.min(1, 1 - pace / MAX_PACE));
  const fraction = MIN_HEIGHT_FRACTION + intensity * (1 - MIN_HEIGHT_FRACTION);
  return Math.round(fraction * totalHeight);
}

function getBarWidth(segment: WorkoutSegment): number {
  return segment.duration_value;
}

interface MiniGraphProps {
  segments: WorkoutSegment[];
  height?: number;
}

export function MiniGraph({ segments, height = 48 }: MiniGraphProps) {
  if (segments.length === 0) return null;

  const totalWidth = segments.reduce((sum, seg) => sum + getBarWidth(seg), 0);
  if (totalWidth === 0) return null;

  return (
    <div
      className="flex items-end gap-px overflow-hidden rounded"
      style={{ height }}
    >
      {segments.map((segment, i) => {
        const barHeight = getBarHeight(segment, height);
        const widthPct = (getBarWidth(segment) / totalWidth) * 100;

        return (
          <div
            key={i}
            className="rounded-sm"
            style={{
              height: barHeight,
              width: `${widthPct}%`,
              minWidth: 2,
              backgroundColor: getSegmentDisplayColor(segment),
            }}
          />
        );
      })}
    </div>
  );
}
