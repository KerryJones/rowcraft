import { createSupabaseAdmin } from '@/lib/supabase/admin';

export async function getOverviewStats() {
  const supabase = createSupabaseAdmin();

  const [users, sessions, workouts] = await Promise.all([
    supabase.from('profiles').select('*', { count: 'exact', head: true }),
    supabase.from('workout_results').select('*', { count: 'exact', head: true }),
    supabase.from('workouts').select('*', { count: 'exact', head: true }),
  ]);

  if (users.error) throw new Error(`Users count failed: ${users.error.message}`);
  if (sessions.error) throw new Error(`Sessions count failed: ${sessions.error.message}`);
  if (workouts.error) throw new Error(`Workouts count failed: ${workouts.error.message}`);

  return {
    totalUsers: users.count ?? 0,
    totalSessions: sessions.count ?? 0,
    totalWorkouts: workouts.count ?? 0,
  };
}

export async function getActiveUsers7d() {
  const supabase = createSupabaseAdmin();

  const { data, error } = await supabase.rpc('admin_active_users_7d');
  if (error) throw new Error(`Active users query failed: ${error.message}`);
  return (data as number) ?? 0;
}

export async function getTotalMeters() {
  const supabase = createSupabaseAdmin();

  const { data, error } = await supabase.rpc('admin_total_meters');
  if (error) throw new Error(`Total meters query failed: ${error.message}`);
  return (data as number) ?? 0;
}

export async function getRecentSessions(limit = 20) {
  const supabase = createSupabaseAdmin();

  const { data, error } = await supabase
    .from('workout_results')
    .select('id, started_at, total_distance, total_time, profiles(display_name), workouts(title)')
    .order('started_at', { ascending: false })
    .limit(limit);

  if (error) throw new Error(`Recent sessions query failed: ${error.message}`);

  return data.map((r) => {
    const profiles = r.profiles as unknown as { display_name: string | null } | null;
    const workouts = r.workouts as unknown as { title: string } | null;
    return {
      id: r.id,
      startedAt: r.started_at,
      totalDistance: r.total_distance ?? 0,
      totalTime: r.total_time ?? 0,
      userName: profiles?.display_name ?? 'Anonymous',
      workoutTitle: workouts?.title ?? 'Free Row',
    };
  });
}

export async function getPopularWorkouts(limit = 10) {
  const supabase = createSupabaseAdmin();

  const { data, error } = await supabase
    .from('workouts')
    .select('id, title, fork_count, profiles(display_name)')
    .order('fork_count', { ascending: false })
    .limit(limit);

  if (error) throw new Error(`Popular workouts query failed: ${error.message}`);

  return data.map((w) => {
    const profile = w.profiles as unknown as { display_name: string | null } | null;
    return {
      id: w.id,
      title: w.title,
      forkCount: w.fork_count,
      authorName: profile?.display_name ?? 'Anonymous',
    };
  });
}
