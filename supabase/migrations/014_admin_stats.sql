-- Admin dashboard aggregate functions (bypass RLS via security definer)

create or replace function admin_total_meters()
returns bigint
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select coalesce(sum(total_distance), 0) from public.workout_results;
$$;

create or replace function admin_active_users_7d()
returns bigint
language sql
stable
security definer
set search_path = public, pg_catalog
as $$
  select count(distinct user_id)
  from public.workout_results
  where started_at >= now() - interval '7 days';
$$;
