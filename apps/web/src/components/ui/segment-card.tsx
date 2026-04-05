import type { WorkoutSegment, SegmentType } from '@/lib/types';
import { formatSegmentType, formatSegmentDuration, formatPace } from '@/lib/utils/format';
import { resolveIntensityToPace, getEffectiveFtp, formatWatts, intensityToWatts } from '@/lib/utils/ftp';

const SEGMENT_DOT: Record<SegmentType, string> = {
  work: 'bg-blue-500',
  rest: 'bg-gray-500',
  warmup: 'bg-emerald-500',
  cooldown: 'bg-yellow-500',
};

const HR_ZONE_BADGE: Record<number, string> = {
  1: 'bg-green-500/20 text-green-400',
  2: 'bg-emerald-500/20 text-emerald-400',
  3: 'bg-yellow-500/20 text-yellow-400',
  4: 'bg-orange-500/20 text-orange-400',
  5: 'bg-red-500/20 text-red-400',
};

interface SegmentCardProps {
  segment: WorkoutSegment;
  index: number;
  ftpWatts?: number | null;
}

export function SegmentCard({ segment, index, ftpWatts }: SegmentCardProps) {
  const ftp = getEffectiveFtp(ftpWatts ?? null);
  const durationLabel = formatSegmentDuration(segment);
  const typeLabel = formatSegmentType(segment.type);

  const primaryLabel = `#${index + 1} ${typeLabel} \u00b7 ${durationLabel}`;

  return (
    <div className="rounded-lg border border-gray-800 bg-gray-900 p-3">
      {/* Primary line */}
      <div className="flex items-center gap-2">
        <div className={`h-2.5 w-2.5 shrink-0 rounded-full ${SEGMENT_DOT[segment.type]}`} />
        <span className="text-sm font-medium text-white">{primaryLabel}</span>
      </div>

      {/* Secondary line: intensity, SPM, HR zone */}
      {(segment.target_intensity || segment.target_stroke_rate || segment.target_hr_zone) && (
        <div className="ml-[18px] mt-1.5 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-gray-400">
          {segment.target_intensity && (() => {
            const { paceMid } = resolveIntensityToPace(segment.target_intensity, ftp);
            const midPct = Math.round((segment.target_intensity.min + segment.target_intensity.max) / 2);
            const watts = intensityToWatts(midPct, ftp);
            return (
              <span>
                {formatPace(paceMid)}/500m{' '}
                <span className="text-gray-500">({midPct}% FTP / {formatWatts(watts)})</span>
              </span>
            );
          })()}
          {segment.target_stroke_rate && (
            <span>
              {segment.target_stroke_rate.min}–{segment.target_stroke_rate.max} spm
            </span>
          )}
          {segment.target_hr_zone && (
            <span className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${HR_ZONE_BADGE[segment.target_hr_zone] ?? 'bg-gray-700 text-gray-300'}`}>
              Z{segment.target_hr_zone}
            </span>
          )}
        </div>
      )}
    </div>
  );
}
