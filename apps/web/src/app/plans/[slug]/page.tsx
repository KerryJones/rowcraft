import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import Link from 'next/link';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { TrainingPlan } from '@/lib/types';
import { formatDifficulty } from '@/lib/utils/format';
import { PlanWeeksAccordion } from './plan-weeks';
import { Calendar, Dumbbell, Pencil } from 'lucide-react';

interface PageProps {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const supabase = await createSupabaseServer();
  const { data } = await supabase
    .from('training_plans')
    .select('title, description')
    .eq('slug', slug)
    .eq('is_active', true)
    .single();

  if (!data) return { title: 'Plan Not Found — RowCraft' };

  return {
    title: `${data.title} — RowCraft`,
    description: data.description || 'A RowCraft training plan',
    openGraph: {
      title: data.title,
      description: data.description || 'A RowCraft training plan',
      type: 'article',
    },
  };
}

const DIFFICULTY_COLORS: Record<string, string> = {
  beginner: 'bg-emerald-500/20 text-emerald-400',
  intermediate: 'bg-yellow-500/20 text-yellow-400',
  advanced: 'bg-red-500/20 text-red-400',
};

export default async function PlanDetailPage({ params }: PageProps) {
  const { slug } = await params;
  const supabase = await createSupabaseServer();
  const user = await getUser();

  const userId = user?.id;
  let query = supabase
    .from('training_plans')
    .select('*')
    .eq('slug', slug);

  if (userId) {
    query = query.or(`is_active.eq.true,author_id.eq.${userId}`);
  } else {
    query = query.eq('is_active', true);
  }

  const { data } = await query.single();

  if (!data) notFound();

  const plan: TrainingPlan = data;

  // Collect all workout IDs referenced in weeks
  const workoutIds = new Set<string>();
  for (const week of plan.weeks) {
    for (const session of week.sessions) {
      workoutIds.add(session.workout_id);
    }
  }

  // Batch-fetch workout titles
  const workoutTitles: Record<string, string> = {};
  if (workoutIds.size > 0) {
    const { data: workouts } = await supabase
      .from('workouts')
      .select('id, title')
      .in('id', Array.from(workoutIds));

    if (workouts) {
      for (const w of workouts) {
        // Strip plan title prefix from workout names
        let title = w.title;
        if (title.startsWith(plan.title)) {
          title = title.slice(plan.title.length).replace(/^[\s:—-]+/, '').trim();
        }
        workoutTitles[w.id] = title || w.title;
      }
    }
  }

  const isOwner = user?.id === plan.author_id;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      {/* Title + badges */}
      <div className="mb-4 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-white">{plan.title}</h1>
          <div className="mt-2 flex items-center gap-2">
            <span
              className={`rounded-full px-3 py-1 text-xs font-medium ${
                DIFFICULTY_COLORS[plan.difficulty] ?? 'bg-gray-800 text-gray-400'
              }`}
            >
              {formatDifficulty(plan.difficulty)}
            </span>
            {plan.tags.map((tag) => (
              <span
                key={tag}
                className="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-500"
              >
                {tag}
              </span>
            ))}
          </div>
        </div>
        {isOwner && (
          <Link
            href={`/plans/builder?edit=${plan.id}`}
            className="flex items-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-500"
          >
            <Pencil className="h-4 w-4" />
            Edit
          </Link>
        )}
      </div>

      {/* Stats */}
      <div className="mb-6 flex items-center gap-6 text-sm text-gray-400">
        <span className="flex items-center gap-1.5">
          <Calendar className="h-4 w-4" />
          {plan.duration_weeks} week{plan.duration_weeks !== 1 ? 's' : ''}
        </span>
        <span className="flex items-center gap-1.5">
          <Dumbbell className="h-4 w-4" />
          {plan.sessions_per_week} sessions/week
        </span>
      </div>

      {/* Description */}
      {plan.description && (
        <p className="mb-8 text-gray-400">{plan.description}</p>
      )}

      {/* Weeks */}
      <PlanWeeksAccordion weeks={plan.weeks} workoutTitles={workoutTitles} />
    </div>
  );
}
