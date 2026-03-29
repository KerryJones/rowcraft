import type { WorkoutSegment, SegmentType } from '@/lib/types';
import { formatSegmentType, formatSegmentDuration, formatPace } from '@/lib/utils/format';
import { paceTenthsToWatts, formatWatts } from '@/lib/utils/ftp';

const SEGMENT_BG: Record<SegmentType, string> = {
  work: 'border-blue-500/30 bg-blue-500/5',
  rest: 'border-gray-500/30 bg-gray-500/5',
  warmup: 'border-emerald-500/30 bg-emerald-500/5',
  cooldown: 'border-yellow-500/30 bg-yellow-500/5',
};

const SEGMENT_DOT: Record<SegmentType, string> = {
  work: 'bg-blue-500',
  rest: 'bg-gray-500',
  warmup: 'bg-emerald-500',
  cooldown: 'bg-yellow-500',
};

interface SegmentCardProps {
  segment: WorkoutSegment;
  index: number;
  instanceLabel?: string;
}

export function SegmentCard({ segment, index, instanceLabel }: SegmentCardProps) {
  return (
    <div className={`rounded-lg border p-3 ${SEGMENT_BG[segment.type]}`}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className={`h-2.5 w-2.5 rounded-full ${SEGMENT_DOT[segment.type]}`} />
          <span className="text-sm font-medium text-white">
            {instanceLabel ?? `#${index + 1}`} {formatSegmentType(segment.type)}
          </span>
        </div>
        <span className="text-sm text-gray-400">{formatSegmentDuration(segment)}</span>
      </div>

      <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-400">
        {segment.target_split && (
          <span>
            Pace: {formatPace(segment.target_split.pace)}/500m ({formatWatts(paceTenthsToWatts(segment.target_split.pace))})
          </span>
        )}
        {segment.target_stroke_rate && (
          <span>
            SPM: {segment.target_stroke_rate.min}–{segment.target_stroke_rate.max}
          </span>
        )}
        {segment.target_hr_zone && (
          <span>HR Zone {segment.target_hr_zone}</span>
        )}
      </div>

      {segment.messages && segment.messages.length > 0 && (
        <div className="mt-2 space-y-1">
          {segment.messages.map((msg, i) => (
            <p key={i} className="text-xs italic text-gray-500">
              &ldquo;{msg.text}&rdquo;
            </p>
          ))}
        </div>
      )}
    </div>
  );
}
