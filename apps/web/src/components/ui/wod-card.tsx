'use client';

import type { Workout } from '@/lib/types';
import { WorkoutGraph } from '@/components/workout-graph';
import { formatWorkoutType, formatDuration, formatDistance, formatPace } from '@/lib/utils/format';
import { resolveIntensityToPace, getEffectiveFtp } from '@/lib/utils/ftp';
import { computeTotalTime, computeTotalDistance, computeSegmentCount } from '@/lib/utils/workout';
import { Flame, RefreshCw } from 'lucide-react';

interface WodCardProps {
  workout: Workout;
  onShuffle: () => void;
  onView: () => void;
  canShuffle?: boolean;
  ftpWatts?: number | null;
}

export function WodCard({ workout, onShuffle, onView, canShuffle = true, ftpWatts }: WodCardProps) {
  const ftp = getEffectiveFtp(ftpWatts ?? null);
  const totalTime = computeTotalTime(workout.segments);
  const totalDistance = computeTotalDistance(workout.segments);
  const segmentCount = computeSegmentCount(workout.segments);

  const workSegs = workout.segments.filter((s) => s.type === 'work' && s.target_intensity);
  const avgPace = (() => {
    if (workSegs.length === 0) return null;
    let totalWeight = 0;
    let weightedSum = 0;
    for (const s of workSegs) {
      const weight = s.duration_value;
      const { paceMid } = resolveIntensityToPace(s.target_intensity!, ftp);
      weightedSum += paceMid * weight;
      totalWeight += weight;
    }
    return totalWeight > 0 ? Math.round(weightedSum / totalWeight) : null;
  })();

  const stats = [
    totalTime !== null
      ? { label: 'TIME', value: formatDuration(totalTime) }
      : totalDistance !== null
        ? { label: 'DISTANCE', value: formatDistance(totalDistance) }
        : { label: 'TIME', value: '—' },
    { label: 'SEGMENTS', value: String(segmentCount) },
    { label: 'AVG PACE', value: avgPace !== null ? formatPace(avgPace) : '—' },
    { label: 'FORKS', value: String(workout.fork_count) },
  ];

  return (
    <div className="flex w-full flex-col gap-3 rounded-xl border border-amber-500/30 bg-gradient-to-br from-amber-600/10 to-gray-900 p-5">
      {/* Header row */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Flame className="h-5 w-5 text-amber-400" />
          <span className="text-sm font-semibold uppercase tracking-wider text-amber-400">
            Workout of the Day
          </span>
        </div>
        {canShuffle && (
          <button
            type="button"
            onClick={onShuffle}
            className="flex cursor-pointer items-center gap-1.5 rounded-lg border border-gray-700 px-2.5 py-1.5 text-xs text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
            title="Shuffle WOD"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            Shuffle
          </button>
        )}
      </div>

      {/* Title */}
      <div className="flex items-center gap-2">
        <span className="rounded-full bg-amber-500/20 px-2.5 py-0.5 text-xs font-medium text-amber-400">
          {formatWorkoutType(workout.workout_type)}
        </span>
        <h3 className="truncate text-lg font-bold text-white">{workout.title}</h3>
      </div>

      {/* Stats row */}
      <div className="flex gap-6">
        {stats.map((stat) => (
          <div key={stat.label} className="flex flex-col">
            <span className="text-[10px] uppercase tracking-wider text-gray-500">{stat.label}</span>
            <span className="font-mono text-lg font-bold text-white">{stat.value}</span>
          </div>
        ))}
      </div>

      {/* Graph */}
      <div className="w-full">
        <WorkoutGraph segments={workout.segments} variant="card" ftpWatts={ftpWatts} />
      </div>

      {/* Description */}
      {workout.description && (
        <p className="line-clamp-3 text-sm text-gray-400">{workout.description}</p>
      )}

      {/* Footer */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex flex-wrap gap-1.5">
          {workout.tags.slice(0, 4).map((tag) => (
            <span
              key={tag}
              className="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-400"
            >
              {tag}
            </span>
          ))}
        </div>
        <button
          type="button"
          onClick={onView}
          className="flex cursor-pointer items-center gap-1.5 rounded-lg bg-amber-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-amber-500"
        >
          View
        </button>
      </div>
    </div>
  );
}
