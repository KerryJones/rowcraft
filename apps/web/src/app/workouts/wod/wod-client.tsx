'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import type { Workout } from '@/lib/types';
import { WorkoutGraph } from '@/components/workout-graph';
import { formatWorkoutType, formatDuration, formatDistance, formatPace } from '@/lib/utils/format';
import { resolveIntensityToPace, getEffectiveFtp } from '@/lib/utils/ftp';
import { computeTotalTime, computeTotalDistance, computeSegmentCount, computeDominantZone } from '@/lib/utils/workout';
import { Flame, RefreshCw, ArrowLeft, Layers, GitFork } from 'lucide-react';

const ZONE_COLORS: Record<number, { text: string; bg: string }> = {
  1: { text: 'text-green-400', bg: 'bg-green-500/20' },
  2: { text: 'text-sky-400', bg: 'bg-sky-500/20' },
  3: { text: 'text-amber-400', bg: 'bg-amber-500/20' },
  4: { text: 'text-orange-400', bg: 'bg-orange-500/20' },
  5: { text: 'text-red-400', bg: 'bg-red-500/20' },
};

function getDaysSinceEpoch(): number {
  const now = new Date();
  const epoch = Date.UTC(2025, 0, 1);
  const current = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  return Math.floor((current - epoch) / 86400000);
}

interface WodClientProps {
  workouts: Workout[];
  ftpWatts?: number | null;
}

export function WodClient({ workouts, ftpWatts }: WodClientProps) {
  const router = useRouter();
  const [wodSeed, setWodSeed] = useState(getDaysSinceEpoch);

  if (workouts.length === 0) {
    return (
      <div className="mx-auto max-w-2xl px-4 py-16 text-center">
        <Flame className="mx-auto mb-4 h-12 w-12 text-gray-600" />
        <p className="text-gray-500">No workouts available for the WOD.</p>
      </div>
    );
  }

  const workout = workouts[wodSeed % workouts.length];
  const ftp = getEffectiveFtp(ftpWatts ?? null);
  const totalTime = computeTotalTime(workout.segments);
  const totalDistance = computeTotalDistance(workout.segments);
  const segmentCount = computeSegmentCount(workout.segments);
  const dominantZone = computeDominantZone(workout.segments);

  const workSegs = workout.segments.filter((s) => s.target_intensity != null);
  const avgPace = (() => {
    if (workSegs.length === 0) return null;
    let totalWeight = 0;
    let weightedSum = 0;
    for (const s of workSegs) {
      const weight = s.duration_value;
      const pace = resolveIntensityToPace(s.target_intensity!, ftp);
      weightedSum += pace * weight;
      totalWeight += weight;
    }
    return totalWeight > 0 ? Math.round(weightedSum / totalWeight) : null;
  })();

  const heroValue = totalDistance !== null
    ? formatDistance(totalDistance)
    : totalTime !== null
      ? formatDuration(totalTime)
      : '—';

  const zoneStyle = dominantZone ? ZONE_COLORS[dominantZone] : null;

  const stats = [
    totalTime !== null
      ? { label: 'TIME', value: formatDuration(totalTime) }
      : totalDistance !== null
        ? { label: 'DISTANCE', value: formatDistance(totalDistance) }
        : null,
    { label: 'SEGMENTS', value: String(segmentCount) },
    { label: 'AVG PACE', value: avgPace !== null ? formatPace(avgPace) : '—' },
  ].filter(Boolean) as { label: string; value: string }[];

  return (
    <div className="mx-auto max-w-2xl px-4 py-8 sm:px-6">
      {/* Back link */}
      <Link
        href="/workouts"
        className="mb-8 inline-flex items-center gap-2 text-sm text-gray-400 transition-colors hover:text-white"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Workouts
      </Link>

      {/* WOD header */}
      <div className="mb-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Flame className="h-6 w-6 text-amber-400" />
          <h1 className="text-2xl font-bold text-amber-400">Workout of the Day</h1>
        </div>
        {workouts.length > 1 && (
          <button
            type="button"
            onClick={() => setWodSeed((s) => s + 1)}
            className="flex cursor-pointer items-center gap-1.5 rounded-lg border border-gray-700 px-3 py-2 text-sm text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
          >
            <RefreshCw className="h-4 w-4" />
            Shuffle
          </button>
        )}
      </div>

      {/* Card */}
      <div className="rounded-xl border border-amber-500/30 bg-gradient-to-br from-amber-600/10 to-gray-900 p-6">
        {/* Hero duration + badges */}
        <div className="mb-4 flex items-center justify-between">
          <span className="font-mono text-4xl font-bold text-white">{heroValue}</span>
          <div className="flex items-center gap-2">
            <span className="rounded-full bg-amber-500/20 px-3 py-1 text-sm font-medium text-amber-400">
              {formatWorkoutType(workout.workout_type)}
            </span>
            {zoneStyle && (
              <span className={`rounded-full px-2.5 py-1 text-sm font-bold ${zoneStyle.text} ${zoneStyle.bg}`}>
                Z{dominantZone}
              </span>
            )}
          </div>
        </div>

        {/* Stats */}
        <div className="mb-4 flex gap-8">
          {stats.map((stat) => (
            <div key={stat.label} className="flex flex-col">
              <span className="text-[10px] uppercase tracking-wider text-gray-500">{stat.label}</span>
              <span className="font-mono text-lg font-bold text-white">{stat.value}</span>
            </div>
          ))}
        </div>

        {/* Graph */}
        <div className="mb-4">
          <WorkoutGraph segments={workout.segments} variant="hero" ftpWatts={ftpWatts} />
        </div>

        {/* Title */}
        <h2 className="mb-2 text-xl font-bold text-white">{workout.title}</h2>

        {/* Description */}
        {workout.description && (
          <p className="mb-4 text-sm text-gray-400">{workout.description}</p>
        )}

        {/* Tags + metadata */}
        <div className="flex items-center justify-between gap-2">
          <div className="flex flex-wrap gap-1.5">
            {workout.tags.map((tag) => (
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
      </div>

      {/* View full details link */}
      <div className="mt-6 text-center">
        <button
          type="button"
          onClick={() => router.push(`/workouts/${workout.id}`)}
          className="cursor-pointer rounded-lg bg-amber-600 px-6 py-3 text-sm font-semibold text-white transition-colors hover:bg-amber-500"
        >
          View Full Workout
        </button>
      </div>
    </div>
  );
}
