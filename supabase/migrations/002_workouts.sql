create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references public.profiles(id) on delete set null,
  title text not null,
  description text,
  workout_type text not null check (workout_type in ('single_distance', 'single_time', 'intervals', 'variable_intervals')),
  segments jsonb not null default '[]'::jsonb,
  tags text[] default '{}',
  is_public boolean default false,
  fork_count int default 0,
  forked_from uuid references public.workouts(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_workouts_author on public.workouts(author_id);
create index idx_workouts_public on public.workouts(is_public) where is_public = true;
create index idx_workouts_tags on public.workouts using gin(tags);
create index idx_workouts_type on public.workouts(workout_type);
