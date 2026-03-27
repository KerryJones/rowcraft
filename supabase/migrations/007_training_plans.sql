-- Training plans and user progress tracking

create table public.training_plans (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  description text,
  difficulty text not null check (difficulty in ('beginner', 'intermediate', 'advanced')),
  duration_weeks int not null,
  sessions_per_week int not null,
  tags text[] default '{}',
  weeks jsonb not null default '[]',
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.user_plan_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  plan_id uuid references public.training_plans(id) on delete cascade not null,
  completed_sessions jsonb default '[]',
  last_viewed_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index idx_plan_progress_user_plan on public.user_plan_progress(user_id, plan_id);
create index idx_plan_progress_user on public.user_plan_progress(user_id);

-- RLS
alter table public.training_plans enable row level security;
alter table public.user_plan_progress enable row level security;

-- training_plans: all authenticated users can read active plans
create policy "Anyone can read active training plans"
  on public.training_plans for select
  to authenticated
  using (is_active = true);

-- user_plan_progress: users manage their own rows
create policy "Users can read own plan progress"
  on public.user_plan_progress for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert own plan progress"
  on public.user_plan_progress for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update own plan progress"
  on public.user_plan_progress for update
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can delete own plan progress"
  on public.user_plan_progress for delete
  to authenticated
  using (auth.uid() = user_id);

-- Reuse the updated_at trigger from migration 005
create trigger set_updated_at_training_plans
  before update on public.training_plans
  for each row execute function public.update_updated_at();

create trigger set_updated_at_user_plan_progress
  before update on public.user_plan_progress
  for each row execute function public.update_updated_at();
