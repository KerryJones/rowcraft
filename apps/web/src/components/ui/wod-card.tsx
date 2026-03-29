'use client';

import type { Workout } from '@/lib/types';
import { MiniGraph } from '@/components/mini-graph';
import { formatWorkoutType, formatDuration } from '@/lib/utils/format';
import { computeTotalTime } from '@/lib/utils/workout';
import { Flame } from 'lucide-react';

interface WodCardProps {
  workout: Workout;
  onClick?: () => void;
}

export function WodCard({ workout, onClick }: WodCardProps) {
  const totalTime = computeTotalTime(workout.segments);

  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full cursor-pointer flex-col gap-4 rounded-xl border border-blue-500/30 bg-gradient-to-br from-blue-600/10 to-gray-900 p-5 text-left transition-colors hover:border-blue-500/50"
    >
      <div className="flex items-center gap-2">
        <Flame className="h-5 w-5 text-blue-400" />
        <span className="text-sm font-semibold uppercase tracking-wider text-blue-400">
          Workout of the Day
        </span>
      </div>

      <MiniGraph segments={workout.segments} height={48} />

      <div>
        <h3 className="text-lg font-bold text-white">{workout.title}</h3>
        <div className="mt-1 flex items-center gap-3 text-sm text-gray-400">
          <span>{formatWorkoutType(workout.workout_type)}</span>
          {totalTime !== null && <span>{formatDuration(totalTime)}</span>}
        </div>
      </div>

      {workout.description && (
        <p className="line-clamp-2 text-sm text-gray-400">{workout.description}</p>
      )}
    </button>
  );
}
