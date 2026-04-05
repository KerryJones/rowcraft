-- Zone 1 Recovery workouts
-- All use target_intensity (FTP percentage), not target_split

-- Easy Spin
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-000000000001',
  'Easy Spin',
  '20 minutes of easy spinning. No pressure, just move.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1200,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,easy,beginner-friendly}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Recovery Paddle
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-000000000002',
  'Recovery Paddle',
  '25 minutes at recovery pace. Gentle strokes, easy breathing.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1500,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":18,"max":20},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,easy}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Stroke Rate Ladder (Easy)
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-000000000003',
  'Stroke Rate Ladder (Easy)',
  'Rate changes at easy pace. Focus on stroke mechanics at each rate.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":16,"max":16},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":18},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":20,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":18},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":16,"max":16},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,technique,rate-ladder}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Light Intervals
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-000000000004',
  'Light Intervals',
  'Gentle intervals with rest. Keep it conversational.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":20},"target_hr_zone":1},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":20},"target_hr_zone":1},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":20},"target_hr_zone":1},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":20},"target_hr_zone":1},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,intervals}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Technique Focus
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-000000000005',
  'Technique Focus',
  'Alternate low and moderate rates at easy pace. Focus on body position.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":18},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":18},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":18},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":18},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":18},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":18},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,technique}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Post-Race Recovery
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-000000000006',
  'Post-Race Recovery',
  'Very light session after a hard effort. Move blood, don''t make power.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":900,"target_intensity":{"min":40,"max":50},"target_stroke_rate":{"min":16,"max":18},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,post-race}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Active Recovery 30
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-000000000007',
  'Active Recovery 30',
  '30 minutes with gentle rate progression. Easy aerobic flush.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":360,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":16,"max":16},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":360,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":18},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":360,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":20,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":360,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":18},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,30-min}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Easy Distance 4K
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-000000000008',
  'Easy Distance 4K',
  '4K at easy pace. Short and light.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"distance","duration_value":500,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":3000,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":20},"target_hr_zone":1},{"type":"cooldown","duration_type":"distance","duration_value":500,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,distance}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Pause and Breathe
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-000000000009',
  'Pause and Breathe',
  '5-minute blocks with generous rest. Practice breathing rhythm.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":20},"target_hr_zone":1},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":20},"target_hr_zone":1},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":60},"target_stroke_rate":{"min":18,"max":20},"target_hr_zone":1},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,breathing}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Flush Row
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '10000000-0000-0000-0000-00000000000a',
  'Flush Row',
  'Quick 20-minute flush. Perfect for active rest days.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":600,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{recovery,short,flush}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();
