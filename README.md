# RowCraft

Structured rowing workouts for Concept2 PM5. Build, follow, and share workouts.

## Architecture

```
rowcraft/
├── apps/
│   ├── mobile/        Flutter (iOS + Android) — BLE connect, real-time display, workout execution
│   └── web/           SvelteKit — workout builder, library browser, history
├── packages/
│   └── shared/        Workout JSON schemas, pre-built workout library
└── supabase/          Migrations, RLS policies, Edge Functions
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x + Riverpod + flutter_reactive_ble + Drift (SQLite) |
| Web | SvelteKit 2 + Svelte 5 + Tailwind CSS 4 |
| Backend | Supabase (Postgres + Auth + Edge Functions) |
| Hosting | Vercel (web), App Store + Google Play (mobile) |

## First-Time Setup

### Prerequisites
- Flutter 3.x SDK
- Node.js 20+
- Supabase CLI

### 1. Mobile App
```bash
cd apps/mobile
flutter create . --org com.rowcraft      # generates ios/ and android/ dirs
flutter pub get
dart run build_runner build               # generates Drift DB code (*.g.dart)
flutter test                              # verify tests pass
```

### 2. Web App
```bash
cd apps/web
npm install
cp .env.example .env                      # fill in Supabase credentials
npm run dev                               # http://localhost:5173
```

### 3. Supabase
```bash
supabase start                            # local Postgres + Auth + Studio
supabase db reset                         # applies migrations + seeds workout library
```

## Running Tests

### Mobile
```bash
cd apps/mobile
flutter test
```

### Web
```bash
cd apps/web
npx vitest run
```

## Key Design Decisions

- **Dark theme default** — rowers are in gyms/garages, dark UI reduces glare
- **Offline-first** — workouts persist to SQLite via Drift, sync when online
- **No Web Bluetooth** — web is for building/browsing only, BLE is mobile-only
- **Split times in tenths of seconds** — matches Concept2 convention (2:00.0 = 1200)
- **PM5 data via notifications only** — never use BLE reads on PM5 (returns junk)
- **Segment colors** — consistent across platforms: work=blue, rest=gray, warmup=green, cooldown=yellow

## Pre-Built Workout Library

9 workouts ship in `packages/shared/workouts/`:
- **Classics**: 2K Test, 5K Test, 30min Steady State, 10x500m
- **Pete Plan**: Week 1 (Mon/Wed/Fri)
- **Wolverine Plan**: WOD 1
- **British Rowing**: Beginner Session 1
