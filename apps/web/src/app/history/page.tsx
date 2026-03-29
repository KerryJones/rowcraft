import type { Metadata } from 'next';
import { createSupabaseServer, requireAuth } from '@/lib/supabase/server';
import type { WorkoutResult } from '@/lib/types';
import { HistoryClient } from './history-client';

export const metadata: Metadata = {
  title: 'History — RowCraft',
};

export default async function HistoryPage() {
  const user = await requireAuth();
  const supabase = await createSupabaseServer();

  const { data: results } = await supabase
    .from('workout_results')
    .select('*')
    .eq('user_id', user.id)
    .order('started_at', { ascending: false });

  const workoutResults: WorkoutResult[] = results ?? [];

  // Batch-fetch workout titles
  const workoutIds = [
    ...new Set(
      workoutResults
        .map((r) => r.workout_id)
        .filter((id): id is string => id !== null)
    ),
  ];

  const workoutTitles: Record<string, string> = {};
  if (workoutIds.length > 0) {
    const { data: workouts } = await supabase
      .from('workouts')
      .select('id, title')
      .in('id', workoutIds);

    if (workouts) {
      for (const w of workouts) {
        workoutTitles[w.id] = w.title;
      }
    }
  }

  return <HistoryClient results={workoutResults} workoutTitles={workoutTitles} />;
}
