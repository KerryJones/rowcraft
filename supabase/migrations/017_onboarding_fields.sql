-- Add onboarding and HR zone fields to profiles
alter table public.profiles
  add column resting_heart_rate int,
  add column zone_system text not null default 'rowing',
  add column onboarding_completed boolean not null default false;

-- Constraint: zone_system must be 'standard' or 'rowing'
alter table public.profiles
  add constraint profiles_zone_system_check
  check (zone_system in ('standard', 'rowing'));

-- Constraint: resting_heart_rate between 30 and 120
alter table public.profiles
  add constraint profiles_resting_heart_rate_check
  check (resting_heart_rate is null or (resting_heart_rate >= 30 and resting_heart_rate <= 120));
