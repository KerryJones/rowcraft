'use client';

import { useRouter } from 'next/navigation';
import Link from 'next/link';
import type { TrainingPlan } from '@/lib/types';
import { PlanCard } from '@/components/ui/plan-card';
import { Plus } from 'lucide-react';

interface PlansClientProps {
  plans: TrainingPlan[];
  userId: string | null;
}

export function PlansClient({ plans, userId }: PlansClientProps) {
  const router = useRouter();

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6">
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

      {/* Blog link */}
      <p className="mb-6 text-sm text-gray-500">
        New to structured training?{' '}
        <Link href="/blog/why-structured-rowing-training" className="text-blue-400 underline hover:text-blue-300">
          Learn why random erg workouts don&apos;t work
        </Link>{' '}and how plans fix that.
      </p>

      {/* Plan grid */}
      {plans.length === 0 ? (
        <div className="py-16 text-center text-gray-500">
          No training plans found.
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
          {plans.map((plan) => (
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
