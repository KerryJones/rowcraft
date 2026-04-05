-- 2K Race Prep plan workouts
-- All use target_intensity (FTP percentage), not target_split

-- Week 1 Steady
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0001-000000000001',
  '2K Prep Wk1 Steady',
  'Week 1: 30-minute steady state at Z2 to build aerobic base.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1800,"target_intensity":{"min":65,"max":75},"target_stroke_rate":{"min":20,"max":24},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,steady-state,week-1}',
  true
);

-- Week 1 Race Pace 4x500m
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0001-000000000002',
  '2K Prep Wk1 Race Pace 4x500m',
  'Week 1: 4x500m at race pace intensity with 3-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":180,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,race-pace,intervals,week-1}',
  true
);

-- Week 1 Easy 5K
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0001-000000000003',
  '2K Prep Wk1 Easy 5K',
  'Week 1: Easy 5K at low Z2 for recovery and volume.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":5000,"target_intensity":{"min":58,"max":68},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,endurance,week-1}',
  true
);

-- Week 2 Tempo 3K
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0002-000000000001',
  '2K Prep Wk2 Tempo 3K',
  'Week 2: 3K at tempo/threshold pace.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":3000,"target_intensity":{"min":85,"max":96},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,tempo,threshold,week-2}',
  true
);

-- Week 2 Race Pace 6x500m
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0002-000000000002',
  '2K Prep Wk2 Race Pace 6x500m',
  'Week 2: 6x500m at race pace intensity with 2:30 rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":150,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":150,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":150,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":150,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":150,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,race-pace,intervals,week-2}',
  true
);

-- Week 2 Easy 6K
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0002-000000000003',
  '2K Prep Wk2 Easy 6K',
  'Week 2: Easy 6K at low Z2 for recovery and volume.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":6000,"target_intensity":{"min":58,"max":68},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,endurance,week-2}',
  true
);

-- Week 3 Threshold 2x1500m
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0003-000000000001',
  '2K Prep Wk3 Threshold 2x1500m',
  'Week 3: 2x1500m at threshold intensity with 5-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":1500,"target_intensity":{"min":92,"max":105},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":300,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":1500,"target_intensity":{"min":92,"max":105},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":4},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,threshold,week-3}',
  true
);

-- Week 3 Race Pace 8x500m
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0003-000000000002',
  '2K Prep Wk3 Race Pace 8x500m',
  'Week 3: 8x500m at race pace intensity with 2-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":120,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_intensity":{"min":108,"max":122},"target_stroke_rate":{"min":30,"max":34},"target_hr_zone":5},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,race-pace,intervals,week-3}',
  true
);

-- Week 3 Easy Recovery
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0003-000000000003',
  '2K Prep Wk3 Easy Recovery',
  'Week 3: 20-minute easy recovery row at Z1.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":1200,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,recovery,week-3}',
  true
);

-- Week 4 Shakeout
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0004-000000000001',
  '2K Prep Wk4 Shakeout',
  'Week 4: Light shakeout with 3 short pickups to stay sharp before race day.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":30,"target_intensity":{"min":85,"max":96},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":null},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":30,"target_intensity":{"min":85,"max":96},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":null},{"type":"rest","duration_type":"time","duration_value":90,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":30,"target_intensity":{"min":85,"max":96},"target_stroke_rate":{"min":28,"max":32},"target_hr_zone":null},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":45,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,shakeout,week-4}',
  true
);

-- Week 4 Openers
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'f1000000-0000-0000-0004-000000000002',
  '2K Prep Wk4 Openers',
  'Week 4: 4x250m openers at race pace+ with full 4-minute recovery.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":250,"target_intensity":{"min":110,"max":125},"target_stroke_rate":{"min":32,"max":36},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":240,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":250,"target_intensity":{"min":110,"max":125},"target_stroke_rate":{"min":32,"max":36},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":240,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":250,"target_intensity":{"min":110,"max":125},"target_stroke_rate":{"min":32,"max":36},"target_hr_zone":5},{"type":"rest","duration_type":"time","duration_value":240,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":250,"target_intensity":{"min":110,"max":125},"target_stroke_rate":{"min":32,"max":36},"target_hr_zone":5},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{2k-race-prep,race-pace,openers,week-4}',
  true
);
