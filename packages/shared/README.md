# RowCraft Shared Packages

## Schemas

JSON Schema definitions for workout and result data structures.

- `schemas/workout.schema.json` — Workout prescription/template format
- `schemas/workout-definition.schema.json` — YAML workout definition format (source for generated seeds)
- `schemas/result.schema.json` — Completed workout result format
- `hr-zones.json` — single source of truth for the 5-zone boundaries (55/75/85/92/97);
  consumed by `scripts/build-seeds.ts`, mirrored (test-enforced) in web `ftp.ts` and
  mobile `hr_zones.dart`

### Split time convention

All split times are in **tenths of seconds per 500m**, following Concept2's convention:
- 2:00.0/500m = 1200
- 1:45.0/500m = 1050
- 2:15.0/500m = 1350

## Pre-built Workout Library

YAML workout definitions are the source of truth — `make build-seeds` compiles them
(plus `plans/*.yaml`) into `supabase/seeds/gen_*.sql`. Never edit the generated SQL.

Workouts organized by program (`workouts/<program>/`):

- `tests/` — Tests & benchmarks (2K, 5K, 10K, Half Marathon, FTP) and classic workouts
- `pete-plan/` — Pete Plan beginner/intermediate program
- `wolverine/` — Wolverine Plan endurance program
- `british-rowing/` — British Rowing structured sessions
- `2k-12-week/`, `2k-race-prep/` — 2K race programs
- `4min-builder/`, `ftp-builder/`, `return-to-rowing/` — progression programs
- `zone1-recovery/` … `zone5-vo2max/` — single-zone workouts
- `wods/` — workouts of the day

## Training Plans

- `plans/*.yaml` — multi-week plan definitions referencing workout slugs; compiled to
  `supabase/seeds/gen_training_plans.sql` by `make build-seeds`
