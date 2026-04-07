-- Server-side function to delete a user's account and all associated data.
-- Uses security definer to bypass RLS and access auth.users.
-- Only allows users to delete their own account (auth.uid() check).
--
-- Cascade chain: auth.users → profiles (cascade) → workout_results,
-- ftp_history, user_plan_progress (all cascade).
-- workouts.author_id is on delete set null — authored public workouts
-- are preserved but become authorless.
create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Deleting from auth.users cascades through profiles to all child tables.
  -- workouts.author_id becomes null (on delete set null).
  delete from auth.users where id = uid;
end;
$$;

-- Restrict execution to authenticated users only
revoke execute on function public.delete_user_account() from public;
revoke execute on function public.delete_user_account() from anon;
grant execute on function public.delete_user_account() to authenticated;
