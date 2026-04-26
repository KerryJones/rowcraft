# Key Files

## Shared
| Path | Purpose |
|------|---------|
| `packages/shared/schemas/workout.schema.json` | JSON Schema for DB workout segments |
| `packages/shared/schemas/workout-definition.schema.json` | JSON Schema for YAML workout definitions |
| `packages/shared/schemas/result.schema.json` | JSON Schema for result validation |
| `packages/shared/workouts/` | YAML workout definitions (~133 workouts, organized by category) |
| `packages/shared/workouts/_spec.md` | Workout YAML format documentation |
| `scripts/build-seeds.ts` | YAML → SQL build script for workout seed data |
| `supabase/seeds/gen_*.sql` | Generated SQL seed files (do not edit — regenerate with build script) |
| `supabase/seeds/90_training_plans.sql` | Training plan definitions (hand-maintained) |

## Web (`apps/web/src/`) — Next.js App Router
| Path | Purpose |
|------|---------|
| `lib/types.ts` | All TypeScript interfaces (master type definitions) |
| `lib/utils/format.ts` | Display formatting (pace, duration, distance) |
| `lib/utils/ftp.ts` | FTP intensity resolution, power/HR zones, C2 watts↔pace formula |
| `lib/utils/workout.ts` | Workout summary computations |
| `lib/utils/builder-validation.ts` | Validate workout title + segments before save |
| `lib/supabase/server.ts` | Server-side Supabase client (cookie auth) |
| `lib/supabase/client.ts` | Browser-side Supabase client |
| `middleware.ts` | Auth token refresh on every request |
| `instrumentation.ts` | Sentry server/edge initialization (Next.js instrumentation hook) |
| `components/workout-graph.tsx` | Interactive workout visualization |
| `components/ui/builder-segment-item.tsx` | Inline-editable builder segment row (CSS grid, color bar, duration/intensity/SPM inputs, pace preview, move/duplicate/remove actions) |
| `components/ui/workout-card.tsx` | Workout card with MiniGraph |
| `components/ui/segment-card.tsx` | Read-only segment display |
| `components/ui/stats-bar.tsx` | Summary stats (time, distance, segments) |
| `components/ui/wod-card.tsx` | Workout of the Day card |
| `app/error.tsx` | Global error boundary (logs to Sentry, "Try again" reset) |
| `app/not-found.tsx` | Custom 404 page |
| `app/builder/` | Graph-first workout builder |
| `app/workouts/page.tsx` | Workout list with WOD, search, filters |
| `app/workouts/[id]/page.tsx` | Workout detail with hero graph + OG meta |
| `app/plans/builder/` | Training plan builder |
| `app/profile/page.tsx` | Profile page (server component, requires auth) |
| `app/profile/profile-client.tsx` | Profile client component (FTP, C2 link, delete account link) |
| `app/delete-account/page.tsx` | Account deletion page (server component, shows form if authed) |
| `app/delete-account/delete-form.tsx` | Delete confirmation form (type "delete all my data", calls `delete_user_account` RPC) |
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
| `features/workout/workout_engine.dart` | Workout state machine (phases: idle→ready→countingDown→rowing/resting→paused→structuredComplete→finished, auto-pause, pace-fail) |
| `features/workout/workout_provider.dart` | Workout session Riverpod notifier; wraps engine, PM5 reset on load, continueWithFreeRow/finishFromStructuredComplete |
| `features/workout/workout_screen.dart` | Active workout UI (classic mode): stats bar, hero pace, segment detail, up-next preview with fade, completion modal, countdown beeps |
| `features/workout/workout_screen_compact.dart` | Active workout UI (compact mode): 3×2 stat tile grid, HR zone gauge tile |
| `features/workout/hr_zone_gauge.dart` | Garmin-style HR zone gauge (Syncfusion SfRadialGauge): 270° arc with 5 colored zone ranges, active zone highlighted, marker pointer, BPM + zone name centered inside |
| `features/workout/workout_summary_screen.dart` | Post-workout summary (stats grid, combined pace+HR timeline chart, HR zone distribution bar, splits, save/discard) |
| `features/workout/ftp_result_screen.dart` | FTP test result screen (save FTP toggle, combined workout save/discard, save progress overlay) |
| `features/workout/save_auto_nav_mixin.dart` | Mixin for save progress overlay auto-navigation (shared by FTP result + summary screens) |
| `widgets/discard_workout_dialog.dart` | Shared discard workout confirmation dialog |
| `widgets/save_discard_buttons.dart` | Shared Save Workout + Discard button pair |
| `models/workout_time_sample.dart` | Time-series data point (1/sec during workout, for summary charts) |
| `features/workout/pre_workout_screen.dart` | PM5 connection gate before starting |
| `features/workout/rowing_animation.dart` | Animated stick-figure rower (CustomPainter) |
| `services/audio_service.dart` | Countdown beep playback; generates PCM WAV in-memory (sine wave + fade envelope); configures audio session to duck background music |
| `models/personal_record.dart` | PersonalRecord + PrType enum |
| `models/achievement.dart` | Achievement + AchievementType enum with thresholds |
| `services/pr_service.dart` | PR detection, cache, upsert, backfill |
| `services/achievement_service.dart` | Achievement detection (distance, workouts, plans, streaks) |
| `features/achievements/achievements_provider.dart` | Riverpod providers for PRs/achievements + init/backfill |
| `features/achievements/achievements_screen.dart` | Achievements page (PRs + badge grid) |
| `services/supabase_service.dart` | Supabase queries |
| `services/local_db.dart` | Drift ORM (pending results, cached workouts, saved devices) |
| `services/sync_service.dart` | Async result sync to Supabase |
| `services/c2_logbook_service.dart` | Concept2 Logbook OAuth (throws on failure) + result sync API |
| `app/router.dart` | GoRouter route definitions |
| `app/theme.dart` | Dark theme colors + typography |
