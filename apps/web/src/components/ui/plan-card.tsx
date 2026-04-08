'use client';

import type { TrainingPlan } from '@/lib/types';
import { Calendar, Dumbbell } from 'lucide-react';

const DIFFICULTY_BG: Record<string, string> = {
  beginner: 'bg-gradient-to-br from-emerald-600 to-emerald-800',
  intermediate: 'bg-gradient-to-br from-amber-600 to-amber-800',
  advanced: 'bg-gradient-to-br from-red-600 to-red-800',
};


interface PlanCardProps {
  plan: TrainingPlan;
  onClick?: () => void;
}

export function PlanCard({ plan, onClick }: PlanCardProps) {
  const bg = DIFFICULTY_BG[plan.difficulty] ?? 'bg-gradient-to-br from-gray-600 to-gray-800';

  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex aspect-square w-full cursor-pointer flex-col items-center justify-center gap-3 rounded-xl p-4 text-center transition-all hover:scale-[1.02] ${bg}`}
    >
      <h3 className="line-clamp-2 text-lg font-bold text-white">{plan.title}</h3>
      <div className="flex items-center gap-3 text-xs text-white/70">
        <span className="flex items-center gap-1">
          <Calendar className="h-3.5 w-3.5" />
          {plan.duration_weeks}wk
        </span>
        <span className="flex items-center gap-1">
          <Dumbbell className="h-3.5 w-3.5" />
          {plan.sessions_per_week}x/wk
        </span>
      </div>
      {plan.description && (
        <p className="line-clamp-2 text-xs text-white/50">{plan.description}</p>
      )}
    </button>
  );
}
