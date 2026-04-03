'use client';

import type { Workout } from '@/lib/types';
import { WorkoutGraph } from '@/components/workout-graph';
import { formatWorkoutType, formatDuration, formatDistance, formatPace, formatDate, getWorkoutTypeBadgeColor } from '@/lib/utils/format';
import { computeTotalTime, computeTotalDistance, computeSegmentCount } from '@/lib/utils/workout';
import { GitFork } from 'lucide-react';



interface WorkoutCardProps {
  workout: Workout;
  authorName?: string;
  onClick: () => void;
}

export function WorkoutCard({ workout, authorName, onClick }: WorkoutCardProps) {
  const totalTime = computeTotalTime(workout.segments);
  const totalDistance = computeTotalDistance(workout.segments);
  const segmentCount = computeSegmentCount(workout.segments);

  // Compute duration-weighted average work pace
  const workSegs = workout.segments.filter((s) => s.type === 'work' && s.target_split);
  const avgPace = (() => {
    if (workSegs.length === 0) return null;
    let totalWeight = 0;
    let weightedSum = 0;
    for (const s of workSegs) {
      const weight = s.duration_value;
      weightedSum += s.target_split!.pace * weight;
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
    <button
      type="button"
      onClick={onClick}
      className="flex w-full cursor-pointer flex-col gap-3 rounded-xl border border-gray-800 bg-gray-900 p-4 text-left transition-colors hover:border-gray-600"
    >
      {/* Header row */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          <span className={`shrink-0 rounded-full px-2.5 py-0.5 text-xs font-medium ${getWorkoutTypeBadgeColor(workout.workout_type)}`}>
            {formatWorkoutType(workout.workout_type)}
          </span>
          <h3 className="truncate font-bold text-white">{workout.title}</h3>
        </div>
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
        <WorkoutGraph segments={workout.segments} variant="card" />
      </div>

      {/* Description */}
      {workout.description && (
        <p className="line-clamp-3 text-sm text-gray-400">{workout.description}</p>
      )}

      {/* Footer row */}
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
        <span className="shrink-0 text-xs text-gray-500">
          {authorName ? `by ${authorName} · ` : ''}{formatDate(workout.created_at)}
        </span>
      </div>
    </button>
  );
}
