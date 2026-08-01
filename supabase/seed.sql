-- RowCraft Seed Data
-- Generated workout SQL lives in seeds/gen_*.sql (built from YAML definitions)
-- To regenerate: make build-seeds (or: cd scripts && npx tsx build-seeds.ts)
--
-- Zone reference (% of FTP watts). Boundaries come from
-- packages/shared/hr-zones.json — the single source of truth that
-- scripts/build-seeds.ts reads when deriving target_hr_zone from a
-- workout's intensity. Keep this comment in sync with that file.
--   (below 55%)          no zone  | recovery / warmup
--   Z1 Base Aerobic UT2:  55-75%  | 16-20 spm
--   Z2 Aerobic Power UT1: 75-85%  | 18-24 spm
--   Z3 Threshold AT:      85-92%  | 22-28 spm
--   Z4 VO2max TR:         92-97%  | 26-32 spm
--   Z5 Anaerobic AN:     97-100%  | 28-36 spm

-- Functions
\ir seeds/00_functions.sql

-- Workouts (generated from packages/shared/workouts/*.yaml)
\ir seeds/gen_all_workouts.sql

-- Training plans (generated from packages/shared/plans/*.yaml)
\ir seeds/gen_training_plans.sql
