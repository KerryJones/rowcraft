-- Strava integration: OAuth tokens on profiles, sync flag on workout_results.

alter table public.profiles
  add column strava_athlete_id text,
  add column strava_access_token text,
  add column strava_refresh_token text,
  add column strava_token_expires_at bigint;

alter table public.workout_results
  add column synced_to_strava boolean default false;
