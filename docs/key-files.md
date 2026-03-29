# Key Files

## Shared
| Path | Purpose |
|------|---------|
| `packages/shared/schemas/workout.schema.json` | JSON Schema for workout validation |
| `packages/shared/schemas/result.schema.json` | JSON Schema for result validation |
| `packages/shared/workouts/` | 11 pre-built workout JSONs (classics, Pete Plan, etc.) |

## Web (`apps/web/src/`)
| Path | Purpose |
|------|---------|
| `lib/types.ts` | All TypeScript interfaces (master type definitions) |
| `lib/utils/format.ts` | Display formatting (pace, duration, distance) |
| `lib/utils/ftp.ts` | Power/HR zone calculations, C2 formula |
| `lib/utils/workout.ts` | Workout summary computations |
| `lib/components/WorkoutGraphHero.svelte` | Interactive workout visualization (200px) |
| `lib/components/SegmentEditor.svelte` | Segment editor (pace, HR zones, cues) |
| `lib/components/SegmentTimeline.svelte` | Horizontal segment block strip |
| `lib/components/BuilderHeader.svelte` | Collapsible workout metadata header |
| `lib/components/WorkoutCard.svelte` | Workout card with MiniGraph |
| `lib/components/SegmentCard.svelte` | Read-only segment display |
| `lib/components/StatsBar.svelte` | Summary stats (time, distance, segments) |
| `lib/components/WodCard.svelte` | Workout of the Day card |
| `routes/builder/+page.svelte` | Graph-first workout builder |
| `routes/workouts/+page.svelte` | Workout list with WOD, search, filters |
| `routes/workouts/[id]/+page.svelte` | Workout detail with hero graph |
| `routes/plans/builder/+page.svelte` | Training plan builder |

## Mobile (`apps/mobile/lib/`)
| Path | Purpose |
|------|---------|
| `models/workout.dart` | Workout + WorkoutType |
| `models/workout_segment.dart` | Segment types, targets, duration types |
| `models/workout_result.dart` | WorkoutResult + SplitData |
| `models/pm5_data.dart` | Real-time PM5 BLE data model |
| `features/ble/pm5_service.dart` | PM5 BLE connection + data streaming |
| `features/ble/hr_service.dart` | HR monitor BLE connection |
| `features/ble/ble_provider.dart` | Riverpod BLE state management |
| `features/workout/workout_engine.dart` | Workout state machine (phases, segments, auto-pause) |
| `features/workout/workout_provider.dart` | Workout session Riverpod notifier |
| `features/workout/workout_screen.dart` | Active workout UI (hero split, rower animation) |
| `features/workout/pre_workout_screen.dart` | PM5 connection gate before starting |
| `features/workout/rowing_animation.dart` | Animated stick-figure rower (CustomPainter) |
| `services/supabase_service.dart` | Supabase queries |
| `services/local_db.dart` | Drift ORM (pending results, cached workouts, saved devices) |
| `services/sync_service.dart` | Async result sync to Supabase |
| `services/c2_logbook_service.dart` | Concept2 Logbook OAuth + API |
| `app/router.dart` | GoRouter route definitions |
| `app/theme.dart` | Dark theme colors + typography |
