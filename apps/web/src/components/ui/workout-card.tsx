'use client';

import type { Workout } from '@/lib/types';
import { MiniGraph } from '@/components/mini-graph';
import { formatWorkoutType, formatDuration } from '@/lib/utils/format';
import { computeTotalTime, computeSegmentCount } from '@/lib/utils/workout';
import { Clock, Layers, GitFork } from 'lucide-react';

interface WorkoutCardProps {
  workout: Workout;
  onClick?: () => void;
}

export function WorkoutCard({ workout, onClick }: WorkoutCardProps) {
  const totalTime = computeTotalTime(workout.segments);
  const segmentCount = computeSegmentCount(workout.segments);

  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full cursor-pointer flex-col gap-3 rounded-xl border border-gray-800 bg-gray-900 p-4 text-left transition-colors hover:border-gray-700 hover:bg-gray-800/50"
    >
      <MiniGraph segments={workout.segments} height={40} />

      <div className="flex items-start justify-between gap-2">
        <h3 className="line-clamp-1 font-semibold text-white">{workout.title}</h3>
        <span className="shrink-0 rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-400">
          {formatWorkoutType(workout.workout_type)}
        </span>
      </div>

      {workout.description && (
        <p className="line-clamp-2 text-sm text-gray-400">{workout.description}</p>
      )}

      <div className="flex items-center gap-4 text-xs text-gray-500">
        {totalTime !== null && (
          <span className="flex items-center gap-1">
            <Clock className="h-3.5 w-3.5" />
            {formatDuration(totalTime)}
          </span>
        )}
        <span className="flex items-center gap-1">
          <Layers className="h-3.5 w-3.5" />
          {segmentCount} segment{segmentCount !== 1 ? 's' : ''}
        </span>
        {workout.fork_count > 0 && (
          <span className="flex items-center gap-1">
            <GitFork className="h-3.5 w-3.5" />
            {workout.fork_count}
          </span>
        )}
      </div>

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
