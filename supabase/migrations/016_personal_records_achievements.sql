-- personal_records: one row per (user, pr_type), upserted on new PR
create table public.personal_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  pr_type text not null,
  value int not null,
  result_id uuid references public.workout_results(id) on delete set null,
  achieved_at timestamptz not null,
  previous_value int,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, pr_type)
);

-- RLS
alter table public.personal_records enable row level security;

create policy "Users can view own PRs"
  on public.personal_records for select
  using (auth.uid() = user_id);

create policy "Users can insert own PRs"
  on public.personal_records for insert
  with check (auth.uid() = user_id);

create policy "Users can update own PRs"
  on public.personal_records for update
  using (auth.uid() = user_id);

-- Index for per-user queries
create index idx_personal_records_user
  on public.personal_records (user_id);

-- Reuse existing updated_at trigger
create trigger set_personal_records_updated_at
  before update on public.personal_records
  for each row execute function update_updated_at();

-- achievements: one row per (user, achievement_type, threshold), inserted once
create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  achievement_type text not null,
  threshold int not null,
  achieved_at timestamptz not null,
  result_id uuid references public.workout_results(id) on delete set null,
  created_at timestamptz default now(),
  unique (user_id, achievement_type, threshold)
);

-- RLS
alter table public.achievements enable row level security;

create policy "Users can view own achievements"
  on public.achievements for select
  using (auth.uid() = user_id);

create policy "Users can insert own achievements"
  on public.achievements for insert
  with check (auth.uid() = user_id);

-- Index for per-user queries
create index idx_achievements_user
  on public.achievements (user_id);
