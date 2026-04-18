-- Add detailed workout data fields for full Concept2 Logbook sync.
-- These fields enable sending complete workout detail (stroke data, HR
-- min/max, drag factor, timezone) instead of just summary totals.

alter table workout_results
  add column stroke_count int not null default 0,
  add column drag_factor int,
  add column min_heart_rate int,
  add column max_heart_rate int,
  add column ending_heart_rate int,
  add column timezone text not null default 'UTC',
  add column time_samples jsonb;
