'use client';

import type { TrainingPlan } from '@/lib/types';
import { formatDifficulty } from '@/lib/utils/format';
import { Calendar, Dumbbell } from 'lucide-react';

const DIFFICULTY_COLORS: Record<string, string> = {
  beginner: 'bg-emerald-500/20 text-emerald-400',
  intermediate: 'bg-yellow-500/20 text-yellow-400',
  advanced: 'bg-red-500/20 text-red-400',
};

interface PlanCardProps {
  plan: TrainingPlan;
  onClick?: () => void;
}

export function PlanCard({ plan, onClick }: PlanCardProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full cursor-pointer flex-col gap-3 rounded-xl border border-gray-800 bg-gray-900 p-4 text-left transition-colors hover:border-gray-700 hover:bg-gray-800/50"
    >
      <div className="flex items-start justify-between gap-2">
        <h3 className="line-clamp-1 font-semibold text-white">{plan.title}</h3>
        <span
          className={`shrink-0 rounded-full px-2 py-0.5 text-xs font-medium ${DIFFICULTY_COLORS[plan.difficulty] ?? 'bg-gray-800 text-gray-400'}`}
        >
          {formatDifficulty(plan.difficulty)}
        </span>
      </div>

      {plan.description && (
        <p className="line-clamp-2 text-sm text-gray-400">{plan.description}</p>
      )}

      <div className="flex items-center gap-4 text-xs text-gray-500">
        <span className="flex items-center gap-1">
          <Calendar className="h-3.5 w-3.5" />
          {plan.duration_weeks} week{plan.duration_weeks !== 1 ? 's' : ''}
        </span>
        <span className="flex items-center gap-1">
          <Dumbbell className="h-3.5 w-3.5" />
          {plan.sessions_per_week} sessions/wk
        </span>
      </div>

      {plan.tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {plan.tags.slice(0, 4).map((tag) => (
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
