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
└── supabase/migrations/ # 9 SQL migrations
```

## Data Flows

### Workout Creation (Web)
User builds in `/builder` → saves segments as JSONB to `workouts` table → can publish public or keep private.

### Workout Execution (Mobile)
Select workout → pair PM5 via BLE → receive real-time data via notifications → track against targets → save result to Drift (offline) → sync to Supabase + C2 Logbook.

### Result Sync
Completed workout → `PendingResults` table (Drift SQLite) → `sync_service` uploads to Supabase → optionally pushes to C2 Logbook API.

### Training Plans
Browse plans → start plan → complete sessions → track progress in `user_plan_progress` JSONB.

## Key Design Decisions

- **Dark theme only** — rowers train in gyms/garages
- **Offline-first mobile** — Drift SQLite queue with async sync
- **No Web Bluetooth** — web is for building/browsing only, BLE is mobile-only
- **PM5 notifications only** — never BLE reads (returns junk)
- **Split times in tenths** — 2:00/500m = 1200, stored in tenths, displayed as M:SS (no decimal)
- **FTP-relative intensity** — workout targets stored as % of FTP watts (`target_intensity`), not absolute pace. App resolves to pace using user's FTP (default 150W). Mirrors EXR/Zwift approach.
- **YAML workout definitions** — system workouts defined in `packages/shared/workouts/*.yaml`, validated against JSON schema, built to SQL via `scripts/build-seeds.ts`. Supports `interval` compound blocks (work+rest repeated N times) expanded to flat segments at build time.
- **No segment repeat in DB** — each segment is stored individually in the database. The YAML `interval` block is a build-time convenience only.
- **Post-workout flow** — Stop → summary screen (stats, pace/HR charts, splits) → Save/Discard → save progress overlay
- **Supabase RLS** — all access control at DB level
