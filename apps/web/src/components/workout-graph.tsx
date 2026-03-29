'use client';

import type { WorkoutSegment, SegmentType } from '@/lib/types';
import { cn } from '@/lib/utils/cn';
import { formatSegmentDuration } from '@/lib/utils/format';

const SEGMENT_COLORS: Record<SegmentType, string> = {
  work: '#3b82f6',
  rest: '#6b7280',
  warmup: '#22c55e',
  cooldown: '#eab308',
};

const TYPE_ABBREV: Record<SegmentType, string> = {
  work: 'W',
  rest: 'R',
  warmup: 'WU',
  cooldown: 'CD',
};

const MAX_PACE = 1800;
const MIN_HEIGHT_FRACTION = 0.25;
const MAX_HEIGHT = 160;
const MIN_BAR_HEIGHT = 40;

function getBarHeight(segment: WorkoutSegment): number {
  if (!segment.target_split) return MIN_BAR_HEIGHT;
  const pace = segment.target_split.pace;
  const intensity = Math.max(0, Math.min(1, 1 - pace / MAX_PACE));
  const fraction = MIN_HEIGHT_FRACTION + intensity * (1 - MIN_HEIGHT_FRACTION);
  return Math.max(MIN_BAR_HEIGHT, Math.round(fraction * MAX_HEIGHT));
}

function getBarWidth(segment: WorkoutSegment): number {
  return segment.duration_value * (segment.repeat || 1);
}

interface WorkoutGraphProps {
  segments: WorkoutSegment[];
  selectedIndex?: number | null;
  onSelectSegment?: (index: number) => void;
}

export function WorkoutGraph({
  segments,
  selectedIndex,
  onSelectSegment,
}: WorkoutGraphProps) {
  if (segments.length === 0) return null;

  const totalWidth = segments.reduce((sum, seg) => sum + getBarWidth(seg), 0);
  if (totalWidth === 0) return null;

  return (
    <div className="flex flex-col gap-1">
      <div
        className="flex items-end gap-1 overflow-hidden rounded"
        style={{ height: MAX_HEIGHT }}
      >
        {segments.map((segment, i) => {
          const barHeight = getBarHeight(segment);
          const widthPct = (getBarWidth(segment) / totalWidth) * 100;
          const isSelected = selectedIndex === i;
          const isClickable = !!onSelectSegment;

          return (
            <button
              key={i}
              type="button"
              disabled={!isClickable}
              onClick={() => onSelectSegment?.(i)}
              className={cn(
                'rounded-sm transition-all',
                isClickable && 'cursor-pointer hover:opacity-80',
                !isClickable && 'cursor-default',
                isSelected && 'ring-2 ring-white ring-offset-1 ring-offset-gray-950'
              )}
              style={{
                height: barHeight,
                width: `${widthPct}%`,
                minWidth: 24,
                backgroundColor: SEGMENT_COLORS[segment.type],
              }}
            />
          );
        })}
      </div>
      <div className="flex gap-1 overflow-hidden">
        {segments.map((segment, i) => {
          const widthPct = (getBarWidth(segment) / totalWidth) * 100;

          return (
            <div
              key={i}
              className="flex flex-col items-center overflow-hidden text-center"
              style={{ width: `${widthPct}%`, minWidth: 24 }}
            >
              <span className="text-[10px] font-medium text-gray-400">
                {TYPE_ABBREV[segment.type]}
              </span>
              <span className="truncate text-[10px] text-gray-500">
                {formatSegmentDuration(segment)}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
