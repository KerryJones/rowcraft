-- One-time handoff tokens for the mobile OAuth kick-off (C2 / Strava).
--
-- The mobile app cannot set an Authorization header on a browser
-- navigation, so instead of passing the Supabase access token as a query
-- param (which leaks into logs/history), it POSTs to /api/<provider>/auth/start
-- with the token in the header, receives a short-lived one-time handoff id,
-- and opens the browser with only that id in the URL.

create table public.oauth_handoff (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider in ('c2', 'strava')),
  created_at timestamptz not null default now()
);

-- Service-role only: RLS enabled with no policies.
alter table public.oauth_handoff enable row level security;

create index idx_oauth_handoff_user_id on public.oauth_handoff (user_id);
