import type { Metadata } from 'next';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { Workout } from '@/lib/types';
import { normalizeWorkoutSegments } from '@/lib/types';
import { WorkoutsClient } from './workouts-client';

export const metadata: Metadata = {
  title: 'Workouts — RowCraft',
};

export default async function WorkoutsPage() {
  const supabase = await createSupabaseServer();
  const user = await getUser();
  const userId = user?.id;

  let query = supabase
    .from('workouts')
    .select('*')
    .order('created_at', { ascending: false });

  if (userId) {
    query = query.or(`is_public.eq.true,author_id.eq.${userId}`);
  } else {
    query = query.eq('is_public', true);
  }

  const { data } = await query;

  const workouts: Workout[] = (data ?? []).map((w) => ({
    ...w,
    segments: normalizeWorkoutSegments(w.segments ?? []),
  }));

  return <WorkoutsClient workouts={workouts} userId={userId ?? null} />;
}
