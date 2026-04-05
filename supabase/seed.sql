-- RowCraft Seed Data
-- Generated workout SQL lives in seeds/gen_*.sql (built from YAML definitions)
-- To regenerate: make build-seeds (or: cd scripts && npx tsx build-seeds.ts)
--
-- FTP Power Zones Reference (% of FTP watts):
--   Z1 Recovery:   45-60%  | 16-20 spm
--   Z2 Aerobic:    60-75%  | 18-24 spm
--   Z3 Tempo:      75-85%  | 22-28 spm
--   Z4 Threshold:  85-100% | 26-32 spm
--   Z5 VO2max:    100-130% | 28-36 spm

-- Functions
\ir seeds/00_functions.sql

-- Workouts (generated from packages/shared/workouts/*.yaml)
\ir seeds/gen_all_workouts.sql

-- Training plans (hand-maintained)
\ir seeds/90_training_plans.sql
