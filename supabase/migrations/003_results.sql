create table public.workout_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  workout_id uuid references public.workouts(id) on delete set null,
  started_at timestamptz not null,
  finished_at timestamptz,
  total_distance int,
  total_time int,
  avg_split int,
  avg_stroke_rate int,
  avg_heart_rate int,
  avg_watts int,
  calories int,
  splits jsonb,
  synced_to_c2 boolean default false,
  created_at timestamptz default now()
);

create index idx_results_user on public.workout_results(user_id);
create index idx_results_workout on public.workout_results(workout_id);
create index idx_results_started on public.workout_results(started_at desc);
