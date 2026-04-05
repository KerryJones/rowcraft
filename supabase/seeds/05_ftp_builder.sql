-- FTP Builder plan workouts
-- All use target_intensity (FTP percentage), not target_split

-- Week 1 Steady
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0001-000000000002',
  'FTP Builder Wk1 Steady',
  'Week 1: 30-minute steady state at Z2 to build aerobic base.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1800,"target_intensity":{"min":62,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,steady-state,week-1}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 1 Recovery
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0001-000000000003',
  'FTP Builder Wk1 Recovery',
  'Week 1: Easy 20-minute recovery row at Z1.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1200,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,recovery,week-1}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 2 Threshold
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0002-000000000001',
  'FTP Builder Wk2 Threshold',
  'Week 2: 4x5min threshold intervals at Z4 with 2-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,threshold,week-2}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 2 VO2max
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0002-000000000002',
  'FTP Builder Wk2 VO2max',
  'Week 2: 6x2min VO2max intervals at Z5 with 2-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":105,"max":118},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":105,"max":118},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":105,"max":118},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":105,"max":118},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":105,"max":118},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":120,"target_intensity":{"min":105,"max":118},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,vo2max,week-2}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 2 Steady
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0002-000000000003',
  'FTP Builder Wk2 Steady',
  'Week 2: 35-minute steady state at Z2.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":2100,"target_intensity":{"min":62,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,steady-state,week-2}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 3 Threshold
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0003-000000000001',
  'FTP Builder Wk3 Threshold',
  'Week 3: 5x5min threshold intervals at Z4 with 2-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":90,"max":98},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":90,"max":98},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":90,"max":98},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":90,"max":98},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":300,"target_intensity":{"min":90,"max":98},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,threshold,week-3}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 3 VO2max
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0003-000000000002',
  'FTP Builder Wk3 VO2max',
  'Week 3: 8x90s VO2max intervals at Z5 with 90s rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":90,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":90,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":90,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":90,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":90,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":90,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":90,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":90,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,vo2max,week-3}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 3 Steady
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0003-000000000003',
  'FTP Builder Wk3 Steady',
  'Week 3: 40-minute steady state at Z2.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":2400,"target_intensity":{"min":62,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,steady-state,week-3}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 4 Threshold
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0004-000000000001',
  'FTP Builder Wk4 Threshold',
  'Week 4: 3x8min threshold intervals at Z4 with 3-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":480,"target_intensity":{"min":90,"max":98},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":480,"target_intensity":{"min":90,"max":98},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":480,"target_intensity":{"min":90,"max":98},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,threshold,week-4}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 4 VO2max
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0004-000000000002',
  'FTP Builder Wk4 VO2max',
  'Week 4: 5x3min VO2max intervals at Z5 with 3-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":105,"max":115},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":105,"max":115},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":105,"max":115},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":105,"max":115},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":105,"max":115},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,vo2max,week-4}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 4 Steady
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0004-000000000003',
  'FTP Builder Wk4 Steady',
  'Week 4: 40-minute steady state at Z2.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":2400,"target_intensity":{"min":62,"max":70},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,steady-state,week-4}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 5 Threshold
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0005-000000000001',
  'FTP Builder Wk5 Threshold',
  'Week 5: 2x12min threshold intervals at Z4 with 4-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":720,"target_intensity":{"min":92,"max":100},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":240,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":720,"target_intensity":{"min":92,"max":100},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,threshold,week-5}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 5 VO2max
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0005-000000000002',
  'FTP Builder Wk5 VO2max',
  'Week 5: 4x4min VO2max intervals at Z5 with 4-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":240,"target_intensity":{"min":105,"max":115},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":240,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":240,"target_intensity":{"min":105,"max":115},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":240,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":240,"target_intensity":{"min":105,"max":115},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":240,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":240,"target_intensity":{"min":105,"max":115},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":5},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,vo2max,week-5}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 5 Steady
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0005-000000000003',
  'FTP Builder Wk5 Steady',
  'Week 5: 35-minute steady state at Z2.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":2100,"target_intensity":{"min":62,"max":70},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,steady-state,week-5}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 6 Recovery
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0006-000000000001',
  'FTP Builder Wk6 Recovery',
  'Week 6: Easy 20-minute recovery row at Z1.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1200,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,recovery,week-6}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Week 6 Steady
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'e1000000-0000-0000-0006-000000000002',
  'FTP Builder Wk6 Steady',
  'Week 6: 25-minute steady state at Z2.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1500,"target_intensity":{"min":62,"max":72},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp-builder,steady-state,week-6}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();
