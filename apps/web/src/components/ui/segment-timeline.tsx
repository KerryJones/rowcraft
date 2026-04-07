import type { WorkoutSegment } from '@/lib/types';
import { isRestSegment } from '@/lib/types';
import { formatSegmentDuration } from '@/lib/utils/format';
import { getSegmentDisplayColor } from '@/lib/utils/segment-color';

interface SegmentTimelineProps {
  segments: WorkoutSegment[];
}

export function SegmentTimeline({ segments }: SegmentTimelineProps) {
  return (
    <div className="relative space-y-0">
      {segments.map((segment, i) => {
        const color = getSegmentDisplayColor(segment);
        const isRest = isRestSegment(segment);
        const label = isRest ? 'Rest' : segment.target_hr_zone != null ? `Z${segment.target_hr_zone}` : 'Active';

        return (
          <div key={i} className="flex gap-3">
            {/* Timeline line + dot */}
            <div className="flex flex-col items-center">
              <div
                className="h-3 w-3 shrink-0 rounded-full"
                style={{ backgroundColor: color }}
              />
              {i < segments.length - 1 && (
                <div
                  className="w-0.5 flex-1"
                  style={{ backgroundColor: color + '4d' }}
                />
              )}
            </div>

            {/* Content */}
            <div className="pb-4">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium text-white">
                  {label}
                </span>
                <span className="text-sm text-gray-500">
                  {formatSegmentDuration(segment)}
                </span>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
