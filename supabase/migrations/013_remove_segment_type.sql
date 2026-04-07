-- Remove the `type` field from all workout segments and recompute target_hr_zone
-- from target_intensity using the 5-zone model.
--
-- Zone thresholds (% of FTP):
--   < 60%  → zone 1 (recovery)
--   60-75% → zone 2 (aerobic)
--   75-85% → zone 3 (tempo)
--   85-92% → zone 4 (threshold)
--   ≥ 92%  → zone 5 (max)
--
-- Segments with no target_intensity get no target_hr_zone (key removed).

update workouts
set segments = (
  select coalesce(jsonb_agg(
    case
      when (s->>'target_intensity') is null then
        s - 'type' - 'target_hr_zone'
      when (s->>'target_intensity')::int < 60 then
        (s - 'type' - 'target_hr_zone') || '{"target_hr_zone":1}'
      when (s->>'target_intensity')::int < 75 then
        (s - 'type' - 'target_hr_zone') || '{"target_hr_zone":2}'
      when (s->>'target_intensity')::int < 85 then
        (s - 'type' - 'target_hr_zone') || '{"target_hr_zone":3}'
      when (s->>'target_intensity')::int < 92 then
        (s - 'type' - 'target_hr_zone') || '{"target_hr_zone":4}'
      else
        (s - 'type' - 'target_hr_zone') || '{"target_hr_zone":5}'
    end
  ), '[]'::jsonb)
  from jsonb_array_elements(segments) as s
)
where segments is not null;
