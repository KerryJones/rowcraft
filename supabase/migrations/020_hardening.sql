-- Hardening: FK indexes, type CHECK constraints, admin function grants

-- Indexes on foreign keys that lacked them
create index idx_personal_records_result_id on public.personal_records (result_id);
create index idx_achievements_result_id on public.achievements (result_id);
create index idx_ftp_history_source_result_id on public.ftp_history (source_result_id);
create index idx_workouts_forked_from on public.workouts (forked_from);

-- Constrain free-text type columns to the values the app writes.
-- Added NOT VALID first (no ACCESS EXCLUSIVE scan of existing rows),
-- then validated under the weaker SHARE UPDATE EXCLUSIVE lock.
alter table public.personal_records
  add constraint personal_records_pr_type_check
  check (pr_type in (
    'fastest_500m',
    'fastest_1k',
    'fastest_2k',
    'fastest_5k',
    'fastest_6k',
    'fastest_10k',
    'fastest_half_marathon',
    'fastest_marathon',
    'highest_ftp',
    'longest_distance'
  )) not valid;

alter table public.personal_records
  validate constraint personal_records_pr_type_check;

alter table public.achievements
  add constraint achievements_achievement_type_check
  check (achievement_type in (
    'total_distance',
    'workout_count',
    'plan_completed',
    'streak_days'
  )) not valid;

alter table public.achievements
  validate constraint achievements_achievement_type_check;

-- Admin aggregates are service-role only (called via createSupabaseAdmin on web)
revoke execute on function public.admin_total_meters() from public, anon, authenticated;
revoke execute on function public.admin_active_users_7d() from public, anon, authenticated;
grant execute on function public.admin_total_meters() to service_role;
grant execute on function public.admin_active_users_7d() to service_role;
