import type { WorkoutSegment, SegmentType } from '@/lib/types';
import { formatSegmentType, formatSegmentDuration } from '@/lib/utils/format';

const DOT_COLORS: Record<SegmentType, string> = {
  work: 'bg-blue-500',
  rest: 'bg-gray-500',
  warmup: 'bg-emerald-500',
  cooldown: 'bg-yellow-500',
};

const LINE_COLORS: Record<SegmentType, string> = {
  work: 'bg-blue-500/30',
  rest: 'bg-gray-500/30',
  warmup: 'bg-emerald-500/30',
  cooldown: 'bg-yellow-500/30',
};

interface SegmentTimelineProps {
  segments: WorkoutSegment[];
}

export function SegmentTimeline({ segments }: SegmentTimelineProps) {
  return (
    <div className="relative space-y-0">
      {segments.map((segment, i) => (
        <div key={i} className="flex gap-3">
          {/* Timeline line + dot */}
          <div className="flex flex-col items-center">
            <div className={`h-3 w-3 shrink-0 rounded-full ${DOT_COLORS[segment.type]}`} />
            {i < segments.length - 1 && (
              <div className={`w-0.5 flex-1 ${LINE_COLORS[segment.type]}`} />
            )}
          </div>

          {/* Content */}
          <div className="pb-4">
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium text-white">
                {formatSegmentType(segment.type)}
              </span>
              <span className="text-sm text-gray-500">
                {formatSegmentDuration(segment)}
              </span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
