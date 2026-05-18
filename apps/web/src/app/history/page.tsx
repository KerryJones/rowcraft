import type { Metadata } from 'next';
import { createSupabaseServer, requireAuth } from '@/lib/supabase/server';
import type { WorkoutResult } from '@/lib/types';
import { HistoryClient, type HrProfile } from './history-client';

export const metadata: Metadata = {
  title: 'History — RowCraft',
  description: 'Your rowing workout history and results.',
};

export default async function HistoryPage() {
  const user = await requireAuth();
  const supabase = await createSupabaseServer();

  const [{ data: results }, { data: profile }] = await Promise.all([
    supabase
      .from('workout_results')
      .select('*')
      .eq('user_id', user.id)
      .order('started_at', { ascending: false }),
    supabase
      .from('profiles')
      .select('max_heart_rate, resting_heart_rate')
      .eq('id', user.id)
      .maybeSingle(),
  ]);

  const workoutResults: WorkoutResult[] = results ?? [];
  const hrProfile: HrProfile = {
    maxHr: profile?.max_heart_rate ?? null,
    restingHr: profile?.resting_heart_rate ?? null,
  };

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

  return (
    <HistoryClient
      results={workoutResults}
      workoutTitles={workoutTitles}
      hrProfile={hrProfile}
    />
  );
}
