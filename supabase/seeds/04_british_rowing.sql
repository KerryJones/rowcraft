-- British Rowing workouts
-- All use target_intensity (FTP percentage), not target_split

-- Beginner Session 1
insert into public.workouts (id, title, description, workout_type, segments, tags, is_public)
values (
  'd0000000-0000-0000-0000-000000000001',
  'Beginner Session 1',
  'British Rowing beginner session: 5x3min work intervals at tempo pace with 1-minute rest.',
  'variable_intervals',
  '[{"type":"warmup","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":75,"max":82},"target_stroke_rate":{"min":22,"max":26},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":75,"max":82},"target_stroke_rate":{"min":22,"max":26},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":75,"max":82},"target_stroke_rate":{"min":22,"max":26},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":75,"max":82},"target_stroke_rate":{"min":22,"max":26},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":60,"target_intensity":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"time","duration_value":180,"target_intensity":{"min":75,"max":82},"target_stroke_rate":{"min":22,"max":26},"target_hr_zone":3},{"type":"cooldown","duration_type":"time","duration_value":180,"target_intensity":{"min":50,"max":55},"target_stroke_rate":{"min":16,"max":20},"target_hr_zone":1}]'::jsonb,
  '{beginner,british-rowing,structured}',
  true
);
