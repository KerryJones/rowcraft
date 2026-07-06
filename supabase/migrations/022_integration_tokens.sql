-- Move third-party OAuth tokens (C2 Logbook, Strava) out of profiles into a
-- service-role-only table.
--
-- Why: profiles is readable by its owner under RLS, so any compromised user
-- session (or XSS on web) could read the raw C2/Strava tokens. The new table
-- has RLS enabled with NO policies — only the service role (web API routes)
-- can touch it. The non-secret link identifiers (c2_user_id,
-- strava_athlete_id) stay on profiles for "is linked" checks.
--
-- NOTE: this migration moves live data. Coordinate before deploying.

create table public.integration_tokens (
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider in ('c2', 'strava')),
  access_token text not null,
  refresh_token text,
  -- Unix seconds (Strava convention); null for providers without expiry info
  expires_at bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, provider)
);

-- Service-role only: RLS enabled with no policies.
alter table public.integration_tokens enable row level security;

create trigger set_integration_tokens_updated_at
  before update on public.integration_tokens
  for each row execute function update_updated_at();

-- Copy existing tokens (skip empty strings — an empty token row would look
-- "connected" while every sync fails)
insert into public.integration_tokens (user_id, provider, access_token, refresh_token)
select id, 'c2', c2_access_token, c2_refresh_token
from public.profiles
where c2_access_token is not null and c2_access_token <> '';

insert into public.integration_tokens (user_id, provider, access_token, refresh_token, expires_at)
select id, 'strava', strava_access_token, strava_refresh_token, strava_token_expires_at
from public.profiles
where strava_access_token is not null and strava_access_token <> '';

-- Drop the raw token columns from profiles
alter table public.profiles
  drop column c2_access_token,
  drop column c2_refresh_token,
  drop column strava_access_token,
  drop column strava_refresh_token,
  drop column strava_token_expires_at;

-- Users can sever their own integration without service-role access
-- (mobile/web disconnect buttons).
create or replace function public.disconnect_integration(p_provider text)
returns void
language sql
security definer
set search_path = public, pg_catalog
as $$
  delete from public.integration_tokens
  where user_id = auth.uid() and provider = p_provider;
$$;

revoke execute on function public.disconnect_integration(text) from public, anon;
grant execute on function public.disconnect_integration(text) to authenticated, service_role;
