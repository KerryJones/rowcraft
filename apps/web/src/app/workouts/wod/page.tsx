import type { Metadata } from 'next';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { Workout } from '@/lib/types';
import { normalizeWorkoutSegments } from '@/lib/types';
import { WodClient } from './wod-client';

export const metadata: Metadata = {
  title: 'Workout of the Day — RowCraft',
  description: 'Today\'s rowing workout of the day for Concept2 rowers.',
};

export default async function WodPage() {
  const supabase = await createSupabaseServer();
  const user = await getUser();
  const userId = user?.id;

  const { data } = await supabase
    .from('workouts')
    .select('*')
    .eq('is_public', true)
    .order('created_at', { ascending: false });

  const workouts: Workout[] = (data ?? []).map((w) => ({
    ...w,
    segments: normalizeWorkoutSegments(w.segments ?? []),
  }));

  // Exclude test/ramp workouts from WOD pool
  const wodPool = workouts.filter(
    (w) => !w.tags.some((t) => ['ftp', 'ramp', 'test'].includes(t)),
  );

  let ftpWatts: number | null = null;
  if (userId) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('current_ftp_watts')
      .eq('id', userId)
      .single();
    ftpWatts = profile?.current_ftp_watts ?? null;
  }

  return <WodClient workouts={wodPool} ftpWatts={ftpWatts} />;
}
