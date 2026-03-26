# RowCraft Shared Packages

## Schemas

JSON Schema definitions for workout and result data structures.

- `schemas/workout.schema.json` — Workout prescription/template format
- `schemas/result.schema.json` — Completed workout result format

### Split time convention

All split times are in **tenths of seconds per 500m**, following Concept2's convention:
- 2:00.0/500m = 1200
- 1:45.0/500m = 1050
- 2:15.0/500m = 1350

## Pre-built Workout Library

Ready-to-use workouts organized by training plan:

- `workouts/classics/` — Standard benchmarks (2K, 5K, 30min, 10x500m)
- `workouts/pete-plan/` — Pete Plan beginner/intermediate program
- `workouts/wolverine-plan/` — Wolverine Plan endurance program
- `workouts/british-rowing/` — British Rowing structured sessions
