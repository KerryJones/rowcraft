import type { WorkoutSegment } from '@/lib/types';
import { formatDuration, formatDistance } from '@/lib/utils/format';
import { computeTotalTime, computeTotalDistance, computeSegmentCount } from '@/lib/utils/workout';

interface StatsBarProps {
  segments: WorkoutSegment[];
}

export function StatsBar({ segments }: StatsBarProps) {
  const totalTime = computeTotalTime(segments);
  const totalDistance = computeTotalDistance(segments);
  const segmentCount = computeSegmentCount(segments);

  const stats = [
    ...(totalTime !== null ? [{ label: 'Time', value: formatDuration(totalTime) }] : []),
    ...(totalDistance !== null ? [{ label: 'Distance', value: formatDistance(totalDistance) }] : []),
    { label: 'Segments', value: String(segmentCount) },
  ];

  return (
    <div className="flex flex-wrap gap-4 rounded-lg border border-gray-800 bg-gray-900/50 p-3">
      {stats.map((stat) => (
        <div key={stat.label} className="flex flex-col">
          <span className="text-xs text-gray-500">{stat.label}</span>
          <span className="text-sm font-semibold text-white">{stat.value}</span>
        </div>
      ))}
    </div>
  );
}
