-- Seed data for RowCraft pre-built workout library
-- author_id = NULL for system library workouts (not owned by any user)
-- These are publicly browsable by all users

-- Classic workouts
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public) values
(
  'a0000000-0000-0000-0000-000000000001',
  '2K Test',
  'The classic 2000m all-out test piece. The gold standard benchmark for rowing fitness.',
  'single_distance',
  '[{"type": "work", "duration_type": "distance", "duration_value": 2000, "target_split": null, "target_stroke_rate": {"min": 28, "max": 36}, "target_hr_zone": null}]'::jsonb,
  '{test,benchmark,race-pace}',
  true
),
(
  'a0000000-0000-0000-0000-000000000002',
  '5K Test',
  '5000m benchmark test. A test of aerobic endurance and pacing discipline.',
  'single_distance',
  '[{"type": "work", "duration_type": "distance", "duration_value": 5000, "target_split": null, "target_stroke_rate": {"min": 24, "max": 30}, "target_hr_zone": null}]'::jsonb,
  '{test,benchmark,endurance}',
  true
),
(
  'a0000000-0000-0000-0000-000000000003',
  '30 Minute Steady State',
  '30 minutes at a comfortable, conversational pace. The foundation of any training plan.',
  'single_time',
  '[{"type": "work", "duration_type": "time", "duration_value": 1800, "target_split": {"min": 1200, "max": 1350}, "target_stroke_rate": {"min": 18, "max": 22}, "target_hr_zone": 2}]'::jsonb,
  '{steady-state,endurance,beginner-friendly}',
  true
),
(
  'a0000000-0000-0000-0000-000000000004',
  '10 x 500m',
  'Ten 500m intervals with 1 minute rest. A classic interval session for building speed and endurance.',
  'intervals',
  '[{"type": "work", "duration_type": "distance", "duration_value": 500, "target_split": {"min": 1050, "max": 1150}, "target_stroke_rate": {"min": 26, "max": 30}, "target_hr_zone": 4, "repeat": 10}, {"type": "rest", "duration_type": "time", "duration_value": 60, "target_split": null, "target_stroke_rate": null, "target_hr_zone": null, "repeat": 10}]'::jsonb,
  '{intervals,speed,popular}',
  true
),

-- FTP Tests
(
  'a0000000-0000-0000-0000-000000000005',
  '20-Minute FTP Test',
  'Row 20 minutes at maximum sustainable effort. Your average pace is your Functional Threshold Pace. Use this to set training zones.',
  'single_time',
  '[{"type": "work", "duration_type": "time", "duration_value": 1200, "target_split": null, "target_stroke_rate": {"min": 24, "max": 30}, "target_hr_zone": null}]'::jsonb,
  '{ftp,test,benchmark,threshold}',
  true
),
(
  'a0000000-0000-0000-0000-000000000006',
  'Ramp FTP Test',
  'Progressive ramp test to find your Functional Threshold Pace. Starting at 60W (~2:58/500m), intensity increases by 20W every minute until failure. FTP is approximately 65% of peak watts achieved (rowing convention).',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":120,"target_split":{"min":1500,"max":1600},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1740,"max":1800},"target_stroke_rate":{"min":18,"max":22}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1580,"max":1640},"target_stroke_rate":{"min":20,"max":24}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1460,"max":1520},"target_stroke_rate":{"min":20,"max":24}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1370,"max":1430},"target_stroke_rate":{"min":22,"max":26}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1290,"max":1350},"target_stroke_rate":{"min":22,"max":26}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1230,"max":1280},"target_stroke_rate":{"min":24,"max":28}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1170,"max":1220},"target_stroke_rate":{"min":24,"max":28}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1120,"max":1170},"target_stroke_rate":{"min":26,"max":30}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1080,"max":1120},"target_stroke_rate":{"min":26,"max":30}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1040,"max":1080},"target_stroke_rate":{"min":28,"max":32}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":1000,"max":1040},"target_stroke_rate":{"min":28,"max":32}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":970,"max":1000},"target_stroke_rate":{"min":30,"max":34}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":940,"max":970},"target_stroke_rate":{"min":30,"max":34}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":910,"max":940},"target_stroke_rate":{"min":32,"max":36}},{"type":"work","duration_type":"time","duration_value":60,"target_split":{"min":880,"max":910},"target_stroke_rate":{"min":32,"max":38}}]'::jsonb,
  '{ftp,test,benchmark,threshold,ramp}',
  true
),

-- Pete Plan
(
  'b0000000-0000-0000-0000-000000000001',
  'Pete Plan — Week 1 Monday',
  'Pete Plan Week 1: 5000m steady distance piece. Focus on consistent splits and good form.',
  'single_distance',
  '[{"type": "work", "duration_type": "distance", "duration_value": 5000, "target_split": {"min": 1150, "max": 1300}, "target_stroke_rate": {"min": 20, "max": 24}, "target_hr_zone": 3}]'::jsonb,
  '{pete-plan,steady-state,week-1}',
  true
),
(
  'b0000000-0000-0000-0000-000000000002',
  'Pete Plan — Week 1 Wednesday',
  'Pete Plan Week 1: 8 x 500m with 3:30 rest. Build speed with generous recovery.',
  'intervals',
  '[{"type": "work", "duration_type": "distance", "duration_value": 500, "target_split": {"min": 1050, "max": 1150}, "target_stroke_rate": {"min": 26, "max": 32}, "target_hr_zone": 4, "repeat": 8}, {"type": "rest", "duration_type": "time", "duration_value": 210, "target_split": null, "target_stroke_rate": null, "target_hr_zone": null, "repeat": 8}]'::jsonb,
  '{pete-plan,intervals,speed,week-1}',
  true
),
(
  'b0000000-0000-0000-0000-000000000003',
  'Pete Plan — Week 1 Friday',
  'Pete Plan Week 1: 20 minutes steady state. Easy effort, focus on technique.',
  'single_time',
  '[{"type": "work", "duration_type": "time", "duration_value": 1200, "target_split": {"min": 1200, "max": 1400}, "target_stroke_rate": {"min": 18, "max": 22}, "target_hr_zone": 2}]'::jsonb,
  '{pete-plan,steady-state,week-1}',
  true
),

-- Wolverine Plan
(
  'c0000000-0000-0000-0000-000000000001',
  'Wolverine Plan — WOD 1',
  'Wolverine Plan: 4 x 2000m with 5 minutes rest. Steady rate 20-22.',
  'intervals',
  '[{"type": "work", "duration_type": "distance", "duration_value": 2000, "target_split": {"min": 1100, "max": 1250}, "target_stroke_rate": {"min": 20, "max": 22}, "target_hr_zone": 3, "repeat": 4}, {"type": "rest", "duration_type": "time", "duration_value": 300, "target_split": null, "target_stroke_rate": null, "target_hr_zone": null, "repeat": 4}]'::jsonb,
  '{wolverine-plan,endurance,long-intervals}',
  true
),

-- British Rowing
(
  'd0000000-0000-0000-0000-000000000001',
  'British Rowing — Beginner Session 1',
  'Introductory workout: 3 min warmup, 5 x (3 min work / 1 min rest), 3 min cooldown.',
  'variable_intervals',
  '[{"type": "warmup", "duration_type": "time", "duration_value": 180, "target_split": {"min": 1400, "max": 1600}, "target_stroke_rate": {"min": 16, "max": 20}, "target_hr_zone": 1}, {"type": "work", "duration_type": "time", "duration_value": 180, "target_split": {"min": 1200, "max": 1400}, "target_stroke_rate": {"min": 20, "max": 24}, "target_hr_zone": 3, "repeat": 5}, {"type": "rest", "duration_type": "time", "duration_value": 60, "target_split": null, "target_stroke_rate": null, "target_hr_zone": null, "repeat": 5}, {"type": "cooldown", "duration_type": "time", "duration_value": 180, "target_split": {"min": 1400, "max": 1600}, "target_stroke_rate": {"min": 16, "max": 20}, "target_hr_zone": 1}]'::jsonb,
  '{beginner,british-rowing,structured}',
  true
);

-- Add increment_fork_count function used by workout-import edge function
create or replace function public.increment_fork_count(workout_id uuid)
returns void as $$
begin
  update public.workouts
  set fork_count = fork_count + 1
  where id = workout_id;
end;
$$ language plpgsql security definer;
