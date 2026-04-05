-- Wolverine Plan workouts
-- All use target_intensity (FTP percentage), not target_split

-- Wolverine WOD 1
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'c0000000-0000-0000-0000-000000000001',
  'Wolverine WOD 1',
  'Wolverine Plan workout: 4x2000m steady state intervals with 5-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"distance","duration_value":2000,"target_intensity":{"min":65,"max":75},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":2},{"type":"rest","duration_type":"time","duration_value":300,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":2000,"target_intensity":{"min":65,"max":75},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":2},{"type":"rest","duration_type":"time","duration_value":300,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":2000,"target_intensity":{"min":65,"max":75},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":2},{"type":"rest","duration_type":"time","duration_value":300,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":2000,"target_intensity":{"min":65,"max":75},"target_stroke_rate":{"min":24,"max":28},"target_hr_zone":2},{"type":"cooldown","duration_type":"time","duration_value":300,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{wolverine-plan,endurance,long-intervals}',
  true
);
