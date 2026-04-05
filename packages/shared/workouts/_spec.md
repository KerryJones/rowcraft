# RowCraft Workout YAML Spec

System workouts are defined as YAML files in this directory. A build script (`scripts/build-seeds.ts`) validates them and generates SQL for the Supabase database.

## Workout File

Each `.yaml` file defines one workout.

```yaml
id: a0000000-0000-0000-0000-000000000004   # stable UUID
title: "10 x 500m"
description: "Ten 500m intervals with 1 minute rest."
difficulty: intermediate                      # beginner | intermediate | advanced
tags: [intervals, speed, popular]
estimated_duration_minutes: 35                # approximate, for display
segments:
  - type: warmup
    duration: 5:00
    intensity: 50-55%
    stroke_rate: 16-20
    hr_zone: 1
  - type: interval
    reps: 10
    work:
      duration: 500m
      intensity: 88-96%
      stroke_rate: 26-30
      hr_zone: 4
    rest:
      duration: "1:00"
  - type: cooldown
    duration: 5:00
    intensity: 50-55%
    stroke_rate: 16-20
    hr_zone: 1
```

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID string | Stable identifier. Must not change once published. |
| `title` | string | Workout name (max 200 chars). |
| `description` | string | One-line description (max 2000 chars). |
| `difficulty` | enum | `beginner`, `intermediate`, or `advanced`. |
| `tags` | string[] | 1-10 tags for search/filtering. |
| `estimated_duration_minutes` | integer | Approximate total time including rest. |
| `segments` | array | At least one segment. |

## Segment Types

### `warmup`, `work`, `cooldown`

Standard segments with optional targets.

| Field | Format | Required | Description |
|-------|--------|----------|-------------|
| `type` | enum | yes | `warmup`, `work`, or `cooldown` |
| `duration` | string | yes | See Duration Format below |
| `intensity` | string | no | FTP percentage range, e.g. `88-96%` |
| `stroke_rate` | string | no | SPM range, e.g. `26-30` |
| `hr_zone` | integer | no | HR zone 1-5 |
| `messages` | array | no | Coaching cues (see Messages below) |

### `rest`

Recovery between efforts. No targets.

| Field | Format | Required |
|-------|--------|----------|
| `type` | `rest` | yes |
| `duration` | string | yes |

### `interval`

Compound block — work+rest repeated N times. YAML-only; the build script expands to flat segments.

| Field | Format | Required | Description |
|-------|--------|----------|-------------|
| `type` | `interval` | yes | |
| `reps` | integer | yes | 1-50 repetitions |
| `work` | object | yes | Work segment definition (same fields as `work` type above, minus `type`) |
| `rest` | object | no | Rest segment definition. If omitted, no rest between reps. |

**Expansion:** `interval` with reps=3, work+rest produces: W R W R W R (6 flat segments). Without rest: W W W (3 flat segments).

## Duration Format

Human-readable, parsed by the build script:

| Format | Example | Meaning |
|--------|---------|---------|
| `M:SS` | `5:00` | 5 minutes (300 seconds) |
| `SS` | `30` | 30 seconds |
| `Nm` | `500m` | 500 meters (distance) |
| `Ncal` | `100cal` | 100 calories |

Durations with `m` suffix become `duration_type: "distance"`. Durations with `cal` suffix become `duration_type: "calories"`. All others become `duration_type: "time"`.

## Intensity Format

FTP percentage range: `min-max%`

Examples:
- `88-96%` → `{"min": 88, "max": 96}`
- `50-55%` → `{"min": 50, "max": 55}`
- `110-125%` → `{"min": 110, "max": 125}`

Omit entirely for segments with no intensity target (tests, free row).

## Stroke Rate Format

SPM range: `min-max`

Examples:
- `26-30` → `{"min": 26, "max": 30}`
- `16-20` → `{"min": 16, "max": 20}`

Omit entirely for segments with no stroke rate target.

## Messages (Coaching Cues)

```yaml
messages:
  - at: start           # trigger: start, end, M:SS, or Nm
    text: "Push off hard!"
```

| Field | Format | Description |
|-------|--------|-------------|
| `at` | string | `start`, `end`, time offset (`0:30`), or distance offset (`500m`) |
| `text` | string | Coaching cue text |

## Workout Type Inference

The build script infers `workout_type` from segments:

| Condition | Inferred Type |
|-----------|---------------|
| Single work segment, duration is distance | `single_distance` |
| Single work segment, duration is time | `single_time` |
| All work segments identical (from interval block) | `intervals` |
| Mixed segment types or varying targets | `variable_intervals` |

## FTP Intensity Guidelines

| Zone | Name | FTP % | Stroke Rate |
|------|------|-------|-------------|
| Z1 | Recovery | 45-60% | 16-20 spm |
| Z2 | Aerobic | 60-75% | 18-24 spm |
| Z3 | Tempo | 75-85% | 22-28 spm |
| Z4 | Threshold | 85-100% | 26-32 spm |
| Z5 | VO2max | 100-130% | 28-36 spm |

## Build Script

```
npx tsx scripts/build-seeds.ts
```

Reads all `.yaml` files → validates → generates `supabase/seeds/*.sql`. The generated SQL deletes all system workouts (`author_id IS NULL`) then inserts fresh.

## UUID Conventions

| Prefix | Category |
|--------|----------|
| `a0000000` | Classics/benchmarks |
| `b0000000` | Pete Plan week 1 |
| `c0000000` | Wolverine |
| `d0000000` | British Rowing |
| `e0000000` | Pete Plan weeks 2-6 |
| `e1000000` | FTP Builder |
| `f0000000` | Return to Rowing |
| `f1000000` | 2K Race Prep |
| `10000000` | Zone 1 Recovery |
| `20000000` | Zone 2 Aerobic |
| `30000000` | Zone 3 Tempo |
| `40000000` | Zone 4 Threshold |
| `50000000` | Zone 5 VO2max |
| `60000000` | Non-zone WODs |
