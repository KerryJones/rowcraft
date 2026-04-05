-- Zone 3 Tempo workouts
-- All use target_intensity (FTP percentage), not target_split

-- Classic Tempo 5x5
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-000000000001',
  'Classic Tempo 5x5',
  'Five 5-minute tempo efforts. The classic tempo session.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,intervals,classic}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Tempo 3x10
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-000000000002',
  'Tempo 3x10',
  'Three 10-minute tempo blocks. Build sustained tempo fitness.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":600,"target_intensity":{"min":76,"max":84},"target_stroke_rate":{"min":22,"max":26},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":600,"target_intensity":{"min":76,"max":84},"target_stroke_rate":{"min":22,"max":26},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":600,"target_intensity":{"min":76,"max":84},"target_stroke_rate":{"min":22,"max":26},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,intervals,long}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Fartlek Tempo
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-000000000003',
  'Fartlek Tempo',
  'Alternate tempo and easy every 2 minutes. Fartlek-style.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,fartlek}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Tempo Distance Pyramid
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-000000000004',
  'Tempo Distance Pyramid',
  'Distance pyramid at tempo. Peak at 1500m then come back down.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":1000,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":1500,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":1000,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,pyramid,distance}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Rate Ladder Tempo
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-000000000005',
  'Rate Ladder Tempo',
  'Ascending rate at tempo pace. Same effort, different feel.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":76,"max":84},"target_stroke_rate":{"min":22,"max":22},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":76,"max":84},"target_stroke_rate":{"min":24,"max":24},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":76,"max":84},"target_stroke_rate":{"min":26,"max":26},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":76,"max":84},"target_stroke_rate":{"min":28,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":76,"max":84},"target_stroke_rate":{"min":26,"max":26},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,rate-ladder}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Tempo 20
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-000000000006',
  'Tempo 20',
  '20 minutes sustained tempo. No intervals, just hold the effort.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1200,"target_intensity":{"min":76,"max":82},"target_stroke_rate":{"min":24,"max":26},"target_hr_zone":3},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,sustained}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Countdown (8/6/4/2)
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-000000000007',
  'Countdown (8/6/4/2)',
  'Descending intervals, ascending effort. Shorter gets harder.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":480,"target_intensity":{"min":78,"max":82},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":360,"target_intensity":{"min":80,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":240,"target_intensity":{"min":82,"max":86},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":85,"max":90},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,descending,countdown}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Tempo 1K Repeats
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-000000000008',
  'Tempo 1K Repeats',
  'Six 1K repeats at tempo pace.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":1000,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":1000,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":1000,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":1000,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":1000,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":1000,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,intervals,distance}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Swing Tempo
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-000000000009',
  'Swing Tempo',
  'Swing between tempo and easy. Feel the contrast.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":80,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":80,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":80,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":80,"max":85},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,swing}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Long Tempo Build
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  '30000000-0000-0000-0000-00000000000a',
  'Long Tempo Build',
  'Build from aerobic to tempo then ease off. Progressive session.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":600,"target_intensity":{"min":68,"max":75},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"work","duration_type":"time","duration_value":900,"target_intensity":{"min":78,"max":85},"target_stroke_rate":{"min":24,"max":26},"target_hr_zone":3},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":65,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{tempo,build,progression}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();
