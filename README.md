# RowCraft

Structured rowing workouts for Concept2 PM5. Build, follow, and share workouts.

## Architecture

```
rowcraft/
├── apps/
│   ├── mobile/        Flutter (Android) — BLE connect, real-time display, workout execution
│   └── web/           Next.js 15 — workout builder, library browser, history
├── packages/
│   └── shared/        Workout JSON schemas, pre-built workout library
└── supabase/          Migrations, RLS policies
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.32+ (Dart 3.8+) + Riverpod 3 + flutter_reactive_ble + Drift 2.32 (SQLite) |
| Web | Next.js 15 (App Router) + React 19 + Tailwind CSS 4 |
| Backend | Supabase (Postgres + Auth) |
| Hosting | Vercel (web), Google Play (mobile) |

## First-Time Setup

### Prerequisites
- Flutter 3.32+ SDK (Dart 3.8+)
- Node.js 20+
- Supabase CLI
- Android SDK with NDK and cmdline-tools installed

### Quick Setup
```bash
make setup    # sets up supabase + mobile + web
make dev      # starts supabase, shows instructions
```

### Manual Setup

#### Mobile
```bash
cd apps/mobile
flutter create . --org com.rowcraft --platforms android
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
```

#### Web
```bash
cd apps/web
npm install
cp .env.example .env    # fill in Supabase credentials
npm run dev             # http://localhost:3000
```

#### Supabase
```bash
supabase start
supabase db reset       # applies migrations + seeds workout library
```

## Development

```bash
make dev-mobile-cloud   # Flutter on device with cloud Supabase
make dev-mobile         # Flutter with local Supabase
make dev-web            # Next.js at http://localhost:3000
make list               # show all available make commands
```

## Testing

```bash
make test               # run all tests (mobile + web)
make test-mobile        # flutter test
make test-web           # vitest
make check              # typescript type check (web)
```

## Building

```bash
make release            # auto-bump versionCode, build signed AAB for Play Store
make build-apk          # build APK (for testing)
make build-seeds        # regenerate SQL seeds from YAML workout definitions
```

## Key Design Decisions

- **Dark theme only** — rowers are in gyms/garages, dark UI reduces glare
- **Offline-first** — workouts persist to SQLite via Drift, sync when online
- **No Web Bluetooth** — web is for building/browsing only, BLE is mobile-only
- **Split times in tenths of seconds** — matches Concept2 convention (2:00.0 = 1200)
- **PM5 data via notifications only** — never use BLE reads on PM5 (returns junk)
- **Android-only for now** — iOS directory not yet configured

## Pre-Built Workout Library

~137 workouts ship in `packages/shared/workouts/`, organized by category. Includes tests & benchmarks (2K, 5K, 10K, Half Marathon, FTP), Pete Plan, Wolverine Plan, and British Rowing sessions.

## License

**Source-available.** This repository is publicly visible for transparency. All rights reserved — no license granted for commercial use, redistribution, or derivative works.
