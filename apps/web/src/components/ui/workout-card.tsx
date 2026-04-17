'use client';

import type { Workout } from '@/lib/types';
import { WorkoutGraph } from '@/components/workout-graph';
import { formatWorkoutType, formatDuration, formatDistance, getWorkoutTypeBadgeColor } from '@/lib/utils/format';
import { getEffectiveFtp } from '@/lib/utils/ftp';
import { computeTotalDistance, computeSegmentCount, estimateTotalSeconds, computeDominantZone } from '@/lib/utils/workout';
import { GitFork, Layers } from 'lucide-react';

const ZONE_COLORS: Record<number, { text: string; bg: string }> = {
  1: { text: 'text-green-400', bg: 'bg-green-500/20' },
  2: { text: 'text-sky-400', bg: 'bg-sky-500/20' },
  3: { text: 'text-amber-400', bg: 'bg-amber-500/20' },
  4: { text: 'text-orange-400', bg: 'bg-orange-500/20' },
  5: { text: 'text-red-400', bg: 'bg-red-500/20' },
};

interface WorkoutCardProps {
  workout: Workout;
  onClick: () => void;
  ftpWatts?: number | null;
}

export function WorkoutCard({ workout, onClick, ftpWatts }: WorkoutCardProps) {
  const totalDistance = computeTotalDistance(workout.segments);
  const segmentCount = computeSegmentCount(workout.segments);
  const dominantZone = computeDominantZone(workout.segments);
  const estimatedSecs = estimateTotalSeconds(workout.segments, getEffectiveFtp(ftpWatts ?? null));

  // Hero stat: distance for distance workouts, estimated duration for everything else
  const heroValue = totalDistance !== null
    ? formatDistance(totalDistance)
    : formatDuration(estimatedSecs);

  const zoneStyle = dominantZone ? ZONE_COLORS[dominantZone] : null;

  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full cursor-pointer flex-col gap-2.5 rounded-xl border border-gray-800 bg-gray-900 p-4 text-left transition-colors hover:border-gray-600"
    >
      {/* Top row: hero duration + type badge + zone */}
      <div className="flex items-center justify-between gap-2">
        <span className="font-mono text-2xl font-bold text-white">
          {heroValue}
        </span>
        <div className="flex items-center gap-2">
          <span className={`rounded-full px-2.5 py-0.5 text-xs font-medium ${getWorkoutTypeBadgeColor(workout.workout_type)}`}>
            {formatWorkoutType(workout.workout_type)}
          </span>
          {zoneStyle && (
            <span className={`rounded-full px-2 py-0.5 text-xs font-bold ${zoneStyle.text} ${zoneStyle.bg}`}>
              Z{dominantZone}
            </span>
          )}
        </div>
      </div>

      {/* Segment graph */}
      <div className="w-full">
        <WorkoutGraph segments={workout.segments} variant="card" ftpWatts={ftpWatts} />
      </div>

      {/* Title */}
      <h3 className="font-semibold text-white">{workout.title}</h3>

      {/* Metadata + Tags row */}
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
        <div className="flex shrink-0 items-center gap-3 text-xs text-gray-500">
          <span className="flex items-center gap-1">
            <Layers className="h-3 w-3" />
            {segmentCount}
          </span>
          {workout.fork_count > 0 && (
            <span className="flex items-center gap-1">
              <GitFork className="h-3 w-3" />
              {workout.fork_count}
            </span>
          )}
        </div>
      </div>
    </button>
  );
}
