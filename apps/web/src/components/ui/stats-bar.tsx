import type { WorkoutSegment } from '@/lib/types';
import { formatDuration, formatDistance } from '@/lib/utils/format';
import { computeTotalTime, computeTotalDistance, computeSegmentCount } from '@/lib/utils/workout';

interface StatsBarProps {
  segments: WorkoutSegment[];
  forkCount?: number;
}

export function StatsBar({ segments, forkCount }: StatsBarProps) {
  const totalTime = computeTotalTime(segments);
  const totalDistance = computeTotalDistance(segments);
  const segmentCount = computeSegmentCount(segments);

  const stats = [
    ...(totalTime !== null ? [{ label: 'TIME', value: formatDuration(totalTime) }] : []),
    ...(totalDistance !== null ? [{ label: 'DISTANCE', value: formatDistance(totalDistance) }] : []),
    { label: 'SEGMENTS', value: String(segmentCount) },
    ...(forkCount !== undefined ? [{ label: 'FORKS', value: String(forkCount) }] : []),
  ];

  return (
    <div className="flex flex-wrap gap-3">
      {stats.map((stat) => (
        <div
          key={stat.label}
          className="min-w-[100px] rounded-lg border border-gray-800 bg-gray-900 p-4"
        >
          <span className="text-xs uppercase tracking-wider text-gray-500">{stat.label}</span>
          <div className="mt-1 font-mono text-2xl font-bold text-white">{stat.value}</div>
        </div>
      ))}
    </div>
  );
}
