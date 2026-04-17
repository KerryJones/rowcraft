'use client';

import type { Workout } from '@/lib/types';
import { WorkoutGraph } from '@/components/workout-graph';
import { formatWorkoutType, formatDuration, formatDistance } from '@/lib/utils/format';
import { getEffectiveFtp } from '@/lib/utils/ftp';
import { computeTotalDistance, estimateTotalSeconds, computeDominantZone } from '@/lib/utils/workout';
import { Flame, RefreshCw } from 'lucide-react';

const ZONE_LABELS: Record<number, string> = {
  1: 'Z1', 2: 'Z2', 3: 'Z3', 4: 'Z4', 5: 'Z5',
};

const ZONE_COLORS: Record<number, { text: string; bg: string }> = {
  1: { text: 'text-green-400', bg: 'bg-green-500/20' },
  2: { text: 'text-sky-400', bg: 'bg-sky-500/20' },
  3: { text: 'text-amber-300', bg: 'bg-amber-400/20' },
  4: { text: 'text-orange-400', bg: 'bg-orange-500/20' },
  5: { text: 'text-red-400', bg: 'bg-red-500/20' },
};

interface WodCardProps {
  workout: Workout;
  onShuffle: () => void;
  onView: () => void;
  canShuffle?: boolean;
  ftpWatts?: number | null;
}

export function WodCard({ workout, onShuffle, onView, canShuffle = true, ftpWatts }: WodCardProps) {
  const totalDistance = computeTotalDistance(workout.segments);
  const estimatedSecs = estimateTotalSeconds(workout.segments, getEffectiveFtp(ftpWatts ?? null));
  const dominantZone = computeDominantZone(workout.segments);

  // Hero stat: distance for distance workouts, estimated duration for everything else
  const heroValue = totalDistance !== null
    ? formatDistance(totalDistance)
    : formatDuration(estimatedSecs);

  const zoneStyle = dominantZone ? ZONE_COLORS[dominantZone] : null;

  return (
    <button
      type="button"
      onClick={onView}
      className="flex w-full cursor-pointer flex-col gap-2.5 rounded-xl border border-amber-500/30 bg-gradient-to-br from-amber-600/10 to-gray-900 p-4 text-left transition-colors hover:border-amber-500/50"
    >
      {/* Header: WOD label + shuffle */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Flame className="h-4 w-4 text-amber-400" />
          <span className="text-xs font-semibold uppercase tracking-wider text-amber-400">
            Workout of the Day
          </span>
        </div>
        {canShuffle && (
          <button
            type="button"
            onClick={(e) => { e.stopPropagation(); onShuffle(); }}
            className="flex cursor-pointer items-center gap-1.5 rounded-lg border border-gray-700 px-2 py-1 text-xs text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
            title="Shuffle WOD"
          >
            <RefreshCw className="h-3 w-3" />
            Shuffle
          </button>
        )}
      </div>

      {/* Hero row: duration + type + zone */}
      <div className="flex items-center justify-between gap-2">
        <span className="font-mono text-2xl font-bold text-white">
          {heroValue}
        </span>
        <div className="flex items-center gap-2">
          <span className="rounded-full bg-amber-500/20 px-2.5 py-0.5 text-xs font-medium text-amber-400">
            {formatWorkoutType(workout.workout_type)}
          </span>
          {zoneStyle && (
            <span className={`rounded-full px-2 py-0.5 text-xs font-bold ${zoneStyle.text} ${zoneStyle.bg}`}>
              {ZONE_LABELS[dominantZone!]}
            </span>
          )}
        </div>
      </div>

      {/* Graph */}
      <div className="w-full">
        <WorkoutGraph segments={workout.segments} variant="card" ftpWatts={ftpWatts} />
      </div>

      {/* Title */}
      <h3 className="font-semibold text-white">{workout.title}</h3>

      {/* Tags */}
      {workout.tags.length > 0 && (
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
      )}
    </button>
  );
}
