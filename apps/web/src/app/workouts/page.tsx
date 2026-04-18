import type { Metadata } from 'next';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { Workout } from '@/lib/types';
import { normalizeWorkoutSegments } from '@/lib/types';
import { WorkoutsClient } from './workouts-client';

export const metadata: Metadata = {
  title: 'Workouts — RowCraft',
  description: 'Browse structured rowing workouts for Concept2 ergometers.',
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

  // Fetch user's FTP for pace display
  let ftpWatts: number | null = null;
  if (userId) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('current_ftp_watts')
      .eq('id', userId)
      .single();
    ftpWatts = profile?.current_ftp_watts ?? null;
  }

  return <WorkoutsClient workouts={workouts} userId={userId ?? null} ftpWatts={ftpWatts} />;
}
