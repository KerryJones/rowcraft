import type { WorkoutSegment } from '@/lib/types';
import { isRestSegment } from '@/lib/types';
import { formatSegmentDuration, formatPace } from '@/lib/utils/format';
import { resolveIntensityToPace, getEffectiveFtp, formatWatts, intensityToWatts } from '@/lib/utils/ftp';
import { getSegmentDisplayColor } from '@/lib/utils/segment-color';

const HR_ZONE_BADGE: Record<number, string> = {
  1: 'bg-green-500/20 text-green-400',
  2: 'bg-blue-500/20 text-blue-400',
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
  const isRest = isRestSegment(segment);
  const zoneLabel = isRest ? 'REST' : segment.target_hr_zone != null ? `Z${segment.target_hr_zone}` : null;
  const dotColor = getSegmentDisplayColor(segment);

  const primaryLabel = `#${index + 1}${zoneLabel ? ` ${zoneLabel}` : ''} · ${durationLabel}`;

  return (
    <div className="rounded-lg border border-gray-800 bg-gray-900 p-3">
      {/* Primary line */}
      <div className="flex items-center gap-2">
        <div
          className="h-2.5 w-2.5 shrink-0 rounded-full"
          style={{ backgroundColor: dotColor }}
        />
        <span className="text-sm font-medium text-white">{primaryLabel}</span>
      </div>

      {/* Secondary line: intensity, SPM, HR zone badge */}
      {(segment.target_intensity != null || segment.target_stroke_rate != null) && (
        <div className="ml-[18px] mt-1.5 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-gray-400">
          {segment.target_intensity != null && (() => {
            const pace = resolveIntensityToPace(segment.target_intensity, ftp);
            const watts = intensityToWatts(segment.target_intensity, ftp);
            return (
              <span>
                {formatPace(pace)}/500m{' '}
                <span className="text-gray-500">({segment.target_intensity}% FTP / {formatWatts(watts)})</span>
              </span>
            );
          })()}
          {segment.target_stroke_rate != null && (
            <span>
              {segment.target_stroke_rate} spm
            </span>
          )}
          {segment.target_hr_zone != null && (
            <span className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${HR_ZONE_BADGE[segment.target_hr_zone] ?? 'bg-gray-700 text-gray-300'}`}>
              Z{segment.target_hr_zone}
            </span>
          )}
        </div>
      )}
    </div>
  );
}
