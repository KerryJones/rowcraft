-- Migration: Fix workout paces and expand segments
-- The repeat field was removed from the data model but the live database
-- still has old 2-segment workouts with repeat:N. This migration replaces
-- the segments column with the fully expanded, pace-corrected data.

-- 30 Minute Steady State (beginner): 1200-1350 → 1300-1500
update public.workouts set segments = '[{"type":"work","duration_type":"time","duration_value":1800,"target_split":{"min":1300,"max":1500},"target_stroke_rate":{"min":18,"max":22},"target_hr_zone":2}]'::jsonb
where id = 'a0000000-0000-0000-0000-000000000003';

-- 10 x 500m: expand repeats + fix pace 1050-1150 → 1150-1300
update public.workouts set segments = '[{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":30},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":60,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null}]'::jsonb
where id = 'a0000000-0000-0000-0000-000000000004';

-- Pete Plan Wk1 Mon: 1150-1300 → 1200-1400
update public.workouts set segments = '[{"type":"work","duration_type":"distance","duration_value":5000,"target_split":{"min":1200,"max":1400},"target_stroke_rate":{"min":20,"max":24},"target_hr_zone":3}]'::jsonb
where id = 'b0000000-0000-0000-0000-000000000001';

-- Pete Plan Wk1 Wed: expand + fix pace 1050-1150 → 1150-1300
update public.workouts set segments = '[{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":32},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":210,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":32},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":210,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":32},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":210,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":32},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":210,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":32},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":210,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":32},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":210,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":32},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":210,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":500,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":26,"max":32},"target_hr_zone":4},{"type":"rest","duration_type":"time","duration_value":210,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null}]'::jsonb
where id = 'b0000000-0000-0000-0000-000000000002';

-- Wolverine WOD 1: expand + fix pace 1100-1250 → 1150-1300
update public.workouts set segments = '[{"type":"work","duration_type":"distance","duration_value":2000,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":300,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":2000,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":300,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":2000,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":300,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null},{"type":"work","duration_type":"distance","duration_value":2000,"target_split":{"min":1150,"max":1300},"target_stroke_rate":{"min":20,"max":22},"target_hr_zone":3},{"type":"rest","duration_type":"time","duration_value":300,"target_split":null,"target_stroke_rate":null,"target_hr_zone":null}]'::jsonb
where id = 'c0000000-0000-0000-0000-000000000001';

-- Pete Plan Wk2-6 Mon: 1150-1300 → 1200-1400
update public.workouts set segments = jsonb_set(segments, '{0,target_split}', '{"min":1200,"max":1400}'::jsonb)
where id in (
  'e0000000-0000-0000-0001-000000000001',
  'e0000000-0000-0000-0001-000000000002',
  'e0000000-0000-0000-0001-000000000003',
  'e0000000-0000-0000-0001-000000000004',
  'e0000000-0000-0000-0001-000000000005'
);

-- Pete Plan Wk2-6 Wed intervals: fix pace 1000-1100 → 1100-1250 on all work segments
-- These workouts have alternating work/rest segments. Update all work segments.
do $$
declare
  workout_ids uuid[] := array[
    'e0000000-0000-0000-0002-000000000001',
    'e0000000-0000-0000-0002-000000000002',
    'e0000000-0000-0000-0002-000000000003',
    'e0000000-0000-0000-0002-000000000004',
    'e0000000-0000-0000-0002-000000000005'
  ]::uuid[];
  wid uuid;
  seg jsonb;
  new_segments jsonb;
  i int;
begin
  foreach wid in array workout_ids loop
    select segments into seg from public.workouts where id = wid;
    if seg is null then continue; end if;
    new_segments := '[]'::jsonb;
    for i in 0..jsonb_array_length(seg)-1 loop
      if seg->i->>'type' = 'work' then
        new_segments := new_segments || jsonb_build_array(
          jsonb_set(seg->i, '{target_split}', '{"min":1150,"max":1300}'::jsonb)
        );
      else
        new_segments := new_segments || jsonb_build_array(seg->i);
      end if;
    end loop;
    update public.workouts set segments = new_segments where id = wid;
  end loop;
end $$;

-- British Rowing Beginner: fix work segment paces 1200-1400 → 1300-1500
do $$
declare
  seg jsonb;
  new_segments jsonb := '[]'::jsonb;
  i int;
begin
  select segments into seg from public.workouts where id = 'd0000000-0000-0000-0000-000000000001';
  if seg is null then return; end if;
  for i in 0..jsonb_array_length(seg)-1 loop
    if seg->i->>'type' = 'work' then
      new_segments := new_segments || jsonb_build_array(
        jsonb_set(seg->i, '{target_split}', '{"min":1300,"max":1500}'::jsonb)
      );
    else
      new_segments := new_segments || jsonb_build_array(seg->i);
    end if;
  end loop;
  update public.workouts set segments = new_segments where id = 'd0000000-0000-0000-0000-000000000001';
end $$;

-- 2K Race Prep steady state: 1150-1300 → 1200-1400
update public.workouts set segments = jsonb_set(segments, '{0,target_split}', '{"min":1200,"max":1400}'::jsonb)
where id = 'f1000000-0000-0000-0001-000000000001';
