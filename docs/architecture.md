# Architecture

## Overview

RowCraft is a full-stack platform for structured Concept2 rowing workouts. The web app handles workout creation and browsing. The mobile app handles BLE-connected workout execution. Supabase provides auth, database, and edge functions.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x, Riverpod, flutter_reactive_ble, Drift (SQLite) |
| Web | Next.js 15 (App Router), React 19, Tailwind CSS 4 |
| Backend | Supabase (Postgres + Auth) |
| Hosting | Any Node.js host via Docker (standalone output), App Store + Google Play (mobile) |

## Project Structure

```
rowcraft/
├── apps/
│   ├── mobile/lib/
│   │   ├── features/    # auth, ble, workout, history, library, plans, profile
│   │   ├── models/      # Dart data classes
│   │   └── services/    # Supabase, local DB, sync, C2 logbook
│   └── web/src/
│       ├── app/         # Next.js App Router pages + API routes
│       ├── components/  # shared UI components
│       └── lib/         # supabase clients (server/client), utils, types
├── packages/shared/     # JSON schemas, pre-built workouts
└── supabase/migrations/ # 12 SQL migrations
```

## Data Flows

### Workout Creation (Web)
User builds in `/builder` → saves segments as JSONB to `workouts` table → can publish public or keep private.

### Workout Execution (Mobile)
Select workout → pair PM5 via BLE → receive real-time data via notifications → track against targets → save result to Drift (offline) → sync to Supabase + C2 Logbook.

### Workout Library Loading
`workoutLibraryProvider` → `WorkoutRepository.getWorkouts()` reads from `CachedWorkouts` SQLite table (instant). If cache is non-empty, a background `refreshWorkouts()` call updates it silently. If empty (first launch), waits for network. Pull-to-refresh forces an explicit refresh then re-reads cache.

### Result Sync
Completed workout → `PendingResults` table (Drift SQLite) → `sync_service` uploads to Supabase → optionally pushes to C2 Logbook API.

### Training Plans
Browse plans → start plan → complete sessions → track progress in `user_plan_progress` JSONB.

## Key Design Decisions

- **Dark theme only** — rowers train in gyms/garages
- **Offline-first mobile** — workout library cached in `CachedWorkouts` Drift table; results queued in `PendingResults`. Both survive app restarts and airplane mode. `SyncMetadata` table stores last sync timestamps for incremental fetches (`updated_at >= lastSyncedAt`). Full sync runs every 24 h to detect remote deletions.
- **No Web Bluetooth** — web is for building/browsing only, BLE is mobile-only
- **PM5 notifications only** — never BLE reads (returns junk)
- **Split times in tenths** — 2:00/500m = 1200, stored in tenths, displayed as M:SS (no decimal)
- **FTP-relative intensity** — workout targets stored as single integer `% of FTP watts` (`target_intensity: int?`), not absolute pace or ranges. App resolves to pace using user's FTP (default 150W). Mirrors EXR/Zwift approach. Stroke rate is similarly a single integer (`target_stroke_rate: int?`). Standard zone targets: Z1=55%/20spm, Z2=70%/22spm, Z3=83%/24spm, Z4=95%/26spm, Z5=112%/30spm; warmup/cooldown=60%/20spm. Tolerance (±5%) is visual-only at workout execution time.
- **No segment type field** — segments have no `type` field. Behavior is derived from content: rest = no `target_intensity` AND no `target_stroke_rate`. `target_hr_zone` is a derived field auto-computed from `target_intensity` at build/save time using the 5-zone model (<60%→Z1, 60-75%→Z2, 75-85%→Z3, 85-92%→Z4, ≥92%→Z5). Display code reads the stored zone; rest segments (no intensity) show gray.
- **YAML workout definitions** — system workouts defined in `packages/shared/workouts/*.yaml`, validated against JSON schema, built to SQL via `scripts/build-seeds.ts`. Supports `interval` compound blocks (work+rest repeated N times) expanded to flat segments at build time.
- **No segment repeat in DB** — each segment is stored individually in the database. The YAML `interval` block is a build-time convenience only.
- **Post-workout flow** — Stop → summary screen (stats, pace/HR charts, splits) → Save/Discard → save progress overlay
- **Supabase RLS** — all access control at DB level
- **Google-only auth** — email/password removed for beta; Google OAuth is the sole auth method on both platforms
- **Crash reporting** — Sentry integrated on both platforms. Mobile: enabled when `SENTRY_DSN` dart-define is set (disabled in dev by default). Web: `@sentry/nextjs` via `withSentryConfig`; DSN from `NEXT_PUBLIC_SENTRY_DSN`. Same Sentry project/DSN for both. Error boundary at `app/error.tsx` captures uncaught errors.
- **BLE auto-reconnect** — `WorkoutSessionNotifier` watches PM5 connection state and calls `autoReconnect()` on disconnect, with a 10-second cooldown to prevent retry loops
