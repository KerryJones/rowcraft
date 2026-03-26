-- Auto-update updated_at timestamp on row modification
create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function public.update_updated_at();

create trigger set_workouts_updated_at
  before update on public.workouts
  for each row execute function public.update_updated_at();
