-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_results enable row level security;

-- Profiles: users can read/update their own profile
create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- Workouts: public workouts visible to all authenticated users, own workouts always visible
create policy "Users can view own workouts"
  on public.workouts for select using (auth.uid() = author_id);

create policy "Users can view public workouts"
  on public.workouts for select using (is_public = true);

create policy "Users can create workouts"
  on public.workouts for insert with check (auth.uid() = author_id);

create policy "Users can update own workouts"
  on public.workouts for update using (auth.uid() = author_id);

create policy "Users can delete own workouts"
  on public.workouts for delete using (auth.uid() = author_id);

-- Workout results: users can only see/manage their own results
create policy "Users can view own results"
  on public.workout_results for select using (auth.uid() = user_id);

create policy "Users can create own results"
  on public.workout_results for insert with check (auth.uid() = user_id);

create policy "Users can update own results"
  on public.workout_results for update using (auth.uid() = user_id);

create policy "Users can delete own results"
  on public.workout_results for delete using (auth.uid() = user_id);
