-- Benchmark & Classic workouts
-- All use target_intensity (FTP percentage), not target_split

-- 2K Test
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'a0000000-0000-0000-0000-000000000001',
  '2K Test',
  'The gold standard rowing benchmark. 2000 meters, all-out effort.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":2000,"target_intensity":null,"target_stroke_rate":{"min":28,"max":36},"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{test,benchmark,race-pace}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- 5K Test
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'a0000000-0000-0000-0000-000000000002',
  '5K Test',
  'Endurance benchmark. 5000 meters at your best sustainable effort.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":5000,"target_intensity":null,"target_stroke_rate":{"min":24,"max":30},"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{test,benchmark,endurance}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- 30 Minute Steady State
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'a0000000-0000-0000-0000-000000000003',
  '30 Minute Steady State',
  'Foundational aerobic work. Hold a comfortable, sustainable pace for 30 minutes.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1800,"target_intensity":{"min":65,"max":75},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{steady-state,endurance,beginner-friendly}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- 10 x 500m
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'a0000000-0000-0000-0000-000000000004',
  '10 x 500m',
  'Classic speed intervals. 10 hard 500m pieces with 60 seconds rest between each.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":88,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{intervals,speed,popular}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- 20-Minute FTP Test
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'a0000000-0000-0000-0000-000000000005',
  '20-Minute FTP Test',
  'Functional Threshold Power test. Row the hardest pace you can sustain for 20 minutes.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1200,"target_intensity":null,"target_stroke_rate":{"min":24,"max":30},"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{ftp,test,benchmark,threshold}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Ramp FTP Test
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'a0000000-0000-0000-0000-000000000006',
  'Ramp FTP Test',
  'Progressive ramp test. Intensity increases every minute until failure. Last completed stage estimates your FTP.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":120,"target_intensity":{"min":45,"max":50},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":30,"max":35},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":38,"max":42},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":45,"max":50},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":52,"max":58},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":60,"max":65},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":68,"max":72},"target_stroke_rate":{"min":20,"max":24},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":75,"max":80},"target_stroke_rate":{"min":20,"max":24},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":82,"max":88},"target_stroke_rate":{"min":20,"max":24},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":90,"max":95},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":98,"max":103},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":105,"max":110},"target_stroke_rate":{"min":28,"max":34},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":112,"max":118},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":120,"max":125},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":128,"max":133},"target_stroke_rate":{"min":30,"max":36},"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":60,"target_intensity":{"min":135,"max":140},"target_stroke_rate":{"min":30,"max":36},"target_hr_zone":null}]'::jsonb,
  '{ftp,test,benchmark,threshold,ramp}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();

-- Just Row
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'a0000000-0000-0000-0000-000000000007',
  'Just Row',
  'Open rowing session — no targets, no time pressure. Row as long as you like and sync to your C2 Logbook.',
  'single_time',
  '[{"type":"work","duration_type":"time","duration_value":7200,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null}]'::jsonb,
  '{free-row,just-row}',
  true
)
on conflict (id) do update set title = excluded.title, description = excluded.description, workout_type = excluded.workout_type, segments = excluded.segments, tags = excluded.tags, is_public = excluded.is_public, updated_at = now();
