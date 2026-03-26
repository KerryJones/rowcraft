# RowCraft

Monorepo: Flutter mobile + SvelteKit web + Supabase backend for structured rowing workouts on Concept2 PM5.

## Rules

### Ownership & Quality
- You own this entire codebase. A failing test is always your bug.
- Planning sessions use a separate git worktree (`isolation: "worktree"`).

### Code Style
- **Dart**: Dart 3.3+, type hints, immutable models with `copyWith`, Riverpod for state
- **TypeScript**: Strict mode, Svelte 5 runes (`$state`, `$derived`, `$effect`, `$props`)
- **SQL**: Lowercase keywords, snake_case columns, always add indexes on foreign keys

### Design Rules
- **Dark theme only** — both platforms. Rowers are in gyms/garages.
- **Split times in tenths of seconds** — 2:00.0/500m = 1200. Never floating point.
- **PM5 data via BLE notifications only** — never use BLE reads (returns junk).
- Segment colors must match across mobile and web: work=blue, rest=gray, warmup=green, cooldown=yellow.

### Tool Usage
- Prefer Claude Code tools (Read, Edit, Write, Glob, Grep) over Bash equivalents.
- Allowlisted Bash: `make`, `git`, `flutter`, `npm`, `dart`, `npx`, `supabase`.

## Build & Test

### Mobile
```
cd apps/mobile
flutter pub get
dart run build_runner build    # generates *.g.dart for Drift
flutter test                   # runs unit tests
flutter run                    # requires ios/ and android/ dirs — see Setup below
```

### Web
```
cd apps/web
npm install
npm run dev                    # local dev server
npm run check                  # type check
npx vitest                     # runs tests
```

### Supabase
```
supabase start                 # local instance
supabase db reset              # applies migrations + seed
```

## First-Time Setup

After cloning, run these one-time commands:
1. `cd apps/mobile && flutter create . --org com.rowcraft` — generates ios/ and android/ platform dirs
2. `cd apps/mobile && dart run build_runner build` — generates Drift DB code (local_db.g.dart)
3. `cd apps/web && npm install`
4. Copy `apps/web/.env.example` to `apps/web/.env` and fill in Supabase credentials

## Reference Docs

| File | Contents |
|------|----------|
| `README.md` | Architecture overview, tech stack, getting started |
| `packages/shared/README.md` | Workout schema format, split time convention |
| `supabase/migrations/` | Database schema (profiles, workouts, results, RLS) |
| `packages/shared/schemas/` | JSON Schema for workouts and results |
