# Key Files

## Shared
| Path | Purpose |
|------|---------|
| `packages/shared/schemas/workout.schema.json` | JSON Schema for workout validation |
| `packages/shared/schemas/result.schema.json` | JSON Schema for result validation |
| `packages/shared/workouts/` | 11 pre-built workout JSONs (classics, Pete Plan, etc.) |

## Web (`apps/web/src/`) — Next.js App Router
| Path | Purpose |
|------|---------|
| `lib/types.ts` | All TypeScript interfaces (master type definitions) |
| `lib/utils/format.ts` | Display formatting (pace, duration, distance) |
| `lib/utils/ftp.ts` | Power/HR zone calculations, C2 formula |
| `lib/utils/workout.ts` | Workout summary computations |
| `lib/supabase/server.ts` | Server-side Supabase client (cookie auth) |
| `lib/supabase/client.ts` | Browser-side Supabase client |
| `middleware.ts` | Auth token refresh on every request |
| `components/workout-graph.tsx` | Interactive workout visualization |
| `components/ui/segment-editor.tsx` | Segment editor (pace, HR zones, cues) |
| `components/ui/workout-card.tsx` | Workout card with MiniGraph |
| `components/ui/segment-card.tsx` | Read-only segment display |
| `components/ui/stats-bar.tsx` | Summary stats (time, distance, segments) |
| `components/ui/wod-card.tsx` | Workout of the Day card |
| `app/builder/` | Graph-first workout builder |
| `app/workouts/page.tsx` | Workout list with WOD, search, filters |
| `app/workouts/[id]/page.tsx` | Workout detail with hero graph + OG meta |
| `app/plans/builder/` | Training plan builder |
| `app/auth/callback/page.tsx` | Google OAuth callback (server-side token exchange) |
| `app/api/c2/` | C2 Logbook OAuth + sync (server-side) |

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
| `features/workout/workout_screen.dart` | Active workout UI (hero split, pace/SPM guide bars, pause overlay) |
| `features/workout/workout_summary_screen.dart` | Post-workout summary (stats grid, pace/HR charts, splits, save/discard) |
| `models/workout_time_sample.dart` | Time-series data point (1/sec during workout, for summary charts) |
| `features/workout/pre_workout_screen.dart` | PM5 connection gate before starting |
| `features/workout/rowing_animation.dart` | Animated stick-figure rower (CustomPainter) |
| `services/supabase_service.dart` | Supabase queries |
| `services/local_db.dart` | Drift ORM (pending results, cached workouts, saved devices) |
| `services/sync_service.dart` | Async result sync to Supabase |
| `services/c2_logbook_service.dart` | Concept2 Logbook OAuth + API |
| `app/router.dart` | GoRouter route definitions |
| `app/theme.dart` | Dark theme colors + typography |
