-- Functions used by edge functions

create or replace function public.increment_fork_count(workout_id uuid)
returns void as $$
begin
  update public.workouts
  set fork_count = fork_count + 1
  where id = workout_id;
end;
$$ language plpgsql security definer;
