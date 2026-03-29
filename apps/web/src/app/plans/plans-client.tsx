'use client';

import { useState, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import type { TrainingPlan, Difficulty } from '@/lib/types';
import { PlanCard } from '@/components/ui/plan-card';
import { Plus } from 'lucide-react';

type DifficultyTab = 'all' | Difficulty;

interface PlansClientProps {
  plans: TrainingPlan[];
  userId: string | null;
}

export function PlansClient({ plans, userId }: PlansClientProps) {
  const router = useRouter();
  const [tab, setTab] = useState<DifficultyTab>('all');

  const filtered = useMemo(() => {
    if (tab === 'all') return plans;
    return plans.filter((p) => p.difficulty === tab);
  }, [plans, tab]);

  const tabs: { key: DifficultyTab; label: string }[] = [
    { key: 'all', label: 'All' },
    { key: 'beginner', label: 'Beginner' },
    { key: 'intermediate', label: 'Intermediate' },
    { key: 'advanced', label: 'Advanced' },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-3xl font-bold text-white">Training Plans</h1>
        {userId && (
          <Link
            href="/plans/builder"
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-500"
          >
            <Plus className="h-4 w-4" />
            New Plan
          </Link>
        )}
      </div>

      {/* Difficulty tabs */}
      <div className="mb-6 flex gap-1 rounded-lg bg-gray-900 p-1">
        {tabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`cursor-pointer rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
              tab === t.key
                ? 'bg-gray-800 text-white'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Plan grid */}
      {filtered.length === 0 ? (
        <div className="py-16 text-center text-gray-500">
          No training plans found for this difficulty level.
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((plan) => (
            <PlanCard
              key={plan.id}
              plan={plan}
              onClick={() => router.push(`/plans/${plan.slug}`)}
            />
          ))}
        </div>
      )}
    </div>
  );
}
