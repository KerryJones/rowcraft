# RowCraft

Flutter (Android) + Next.js + Supabase monorepo for structured Concept2 PM5 rowing workouts. Mobile executes workouts over BLE; web builds and browses them; the workout library is generated from YAML into SQL seeds.

Background when you need it: `docs/architecture.md` (data flows), `docs/database.md` (schema, RLS), `docs/key-files.md` (file map). Authoring workout or plan YAML is covered by the `rowing-coach` skill, scoped to `packages/shared/**/*.yaml`.

## Units — the top source of bugs here

Three time units coexist; confusing them yields plausible numbers off by 10x.

- **PM5 wire format is centiseconds and decimetres** — time in 0.01 s, distance in 0.1 m, pace in 0.01 s/500 m (byte maps at `apps/mobile/lib/features/ble/pm5_parser.dart:18-19`, `:111-117`). The parser converts distance to metres at `:41`, pace to tenths/500 m at `:75-77`.
- **Stored results are tenths of a second** — `workout_results.total_time` and `avg_split`, formatted by `formatPace`/`formatTimeTenths` at `apps/web/src/lib/utils/format.ts:8`, `:42`. Pace drops the decimal (`2:00`), elapsed time keeps it (`20:00.0`).
- **Segment durations are whole seconds** — `duration_value` is seconds, metres, or calories depending on `duration_type` (`apps/web/src/lib/utils/format.ts:92-103`). Never feed one to a tenths formatter.

## PM5 / BLE

- **Notifications only — never `readCharacteristic`.** Reads return junk. The app uses `subscribeToCharacteristic` (`apps/mobile/lib/features/ble/pm5_service.dart:227`) and, for CSAFE, `writeCharacteristicWithoutResponse` (`:251`). No read exists anywhere under `apps/mobile/lib`; keep it that way.
- **Rest segments must be ≤ 3:00.** The PM5 blanks its screen and stops notifying after 4:00 idle. Longer recovery becomes a separate workout or a low-intensity active-rest segment. Rationale in `.claude/skills/rowing-coach/SKILL.md`.
- **Scanning is deliberately unfiltered — don't "fix" it with a scan filter.** The PM5 advertises `CE060000` only in its scan-response packet, which some Android stacks won't match, so the app scans wide and filters client-side (`pm5_service.dart:95-97`). Polar straps rotate BLE privacy addresses and appear as several `device.id`s, so results are deduped by case-folded name while connect logic still keys off `device.id` (`apps/mobile/lib/features/ble/ble_provider.dart:19-22`).
- **0 and 255 are sentinels, not data.** HR byte `255`/`0` means "no strap" → `null` (`pm5_parser.dart:72-73`); drag factor `0` means "no reading" and is passed as `null` to `copyWith`, which *keeps the previous value* (`:48`). Separately, `resolveSegmentTargetPace() == 0` means "no target" and doubles as the pace-fail enable flag (`apps/mobile/lib/utils/pace_utils.dart:86` → `workout_engine.dart:1098`).

## HR zones — one source of truth, five copies

`packages/shared/hr-zones.json` holds `[55, 75, 85, 92, 97]`. Changing it means changing every mirror, and only two are guarded:

| Copy | Guarded? |
|---|---|
| `apps/web/src/lib/utils/ftp.ts:38` | yes — `apps/web/src/lib/utils/__tests__/hr-zone-boundaries.test.ts` |
| `apps/mobile/lib/utils/hr_zones.dart:46-122` (zone lists) | yes — `apps/mobile/test/utils/hr_zones_boundaries_test.dart` |
| `apps/mobile/lib/utils/hr_zones.dart:185-189` (`estimateHrZone` literals) | **no** |
| `apps/mobile/lib/features/workout/hr_zone_gauge.dart:40` (`_zoneFractions`, expressed 0–1 not 0–100) | **no** |
| `supabase/seed.sql:5-14` (comment block) | **no** — has already drifted once |

`scripts/build-seeds.ts` reads the JSON directly, so seed data and the unguarded copies can disagree silently.

Zone *names* are offset from the obvious reading: in `apps/web/src/lib/utils/ftp.ts:45-91` the `HrZoneName` `'tempo'` is **Z2**, `'threshold'` is Z3, `'vo2max'` is Z4, `'max'` is Z5. The comments at `segment-color.ts:4-8` use the shifted labels ("3: tempo") and are the outlier — go by `ftp.ts`.

## Segments have no type field

Behaviour is derived from content. Rest = no `target_intensity` **and** no `target_stroke_rate`. `target_hr_zone` is precomputed at build/save time and display code reads the stored value rather than recomputing (`apps/web/src/lib/utils/segment-color.ts:14-19`, `apps/mobile/lib/utils/segment_color.dart:9-13`). Migration `013_remove_segment_type.sql` dropped the old column; don't reintroduce it.

Zone `0` and zone `null` are different and coloured differently: a segment with no zone is gray `#6b7280` (`segment-color.ts:11`), but a *live* HR below 55% returns zone `0`, which `zoneColor(0)` deliberately paints green — Z1's colour (`apps/mobile/lib/utils/hr_zones.dart:195-196`). `time_in_zone.dart:42` drops zone 0 from distribution charts entirely.

## Mobile state — traps that look like nothing

- **`copyWith` cannot clear a nullable field on most models.** `BleState` (`apps/mobile/lib/features/ble/ble_provider.dart:139-169`) and `WorkoutSessionState` (`apps/mobile/lib/features/workout/workout_provider.dart:148-215`) use an `Object _sentinel` to distinguish "not passed" from "explicitly null". Every other model — `PM5Data` (`apps/mobile/lib/models/pm5_data.dart:50-76`), `WorkoutEngineState` (`workout_engine.dart:93-135`), `WorkoutSegment`, `WorkoutResult` — uses plain `??`, so `heartRate`, `finishReason`, and `targetHrZone` can never be nulled back out. Check which pattern a model uses before relying on a clear.
- **The engine runs on `package:clock`; the rest of the app runs on `DateTime.now()`.** Only `workout_engine.dart` is testable under `fake_async`. Its timed segments use wall-clock timers rather than PM5 elapsed time on purpose — the PM5 hardware timer keeps counting while the app is paused (`workout_engine.dart:889-892`).
- **`WorkoutSessionNotifier.build()` must use `ref.read`, never `ref.watch`,** for its service singletons (`workout_provider.dart:266-268`). Watching re-runs `build()` after `_cleanup()` has closed `_pm5Controller`, so fresh subscriptions push into a closed `StreamController`.

## Persistence

- **Drift `schemaVersion` is 5** (`apps/mobile/lib/services/local_db.dart:77`). Adding a table or column requires bumping it *and* appending an `if (from < N)` branch to `onUpgrade` (`:82-103`), or existing installs crash on open. Note the pattern at `:89-102`: new sync-status columns are backfilled to "already synced" so results queued before an integration existed aren't replayed into it.
- **Adding a sync target means editing two queries with opposite logic.** `getPendingResults`/`getPendingCount` OR the flags (`:118-122`, `:131-134`); `cleanupSynced` ANDs them (`:205-209`) because a row is only deletable once every target succeeded. Miss the second and rows queue forever.
- **Plan progress writes are not atomic.** `completePlanSession` (`apps/mobile/lib/services/supabase_service.dart:585`) read-modify-writes the whole `user_plan_progress.completed_sessions` JSONB array, so a concurrent write from a second device loses entries — known and accepted for v1 (`:581-584`). Prefer a Postgres RPC doing an atomic `jsonb || jsonb` append over adding a second client-side read-modify-write.
- **Plexo sync is allowlisted to one account.** `apps/mobile/lib/services/plexo_service.dart:58-63` returns `false` unless `display_name` is `kerryjones21`, logging rather than failing. Plexo doing nothing is expected, not a bug to chase.

## Generated code and seeds

- **`*.g.dart` is gitignored, so a fresh checkout does not compile.** Run `dart run build_runner build --delete-conflicting-outputs` before `flutter analyze` or `flutter test`; every CI job does (`.github/workflows/mobile-build.yml:34-42`).
- **Seed SQL is generated and CI fails on drift.** Edit YAML under `packages/shared/`, then `make build-seeds`; `.github/workflows/seeds-check.yml:44` rebuilds and runs `git diff --exit-code` over `supabase/seeds` and `supabase/seed.sql`.
- **Not everything under `supabase/seeds/` is generated** — `00_functions.sql` is hand-written with no YAML source. Only `gen_*.sql` are outputs, and `build-seeds.ts:504-508` deletes *every* file starting with `gen_` before writing, so a hand-written file with that prefix is destroyed on the next build.
- **Only two generated files are ever loaded.** `supabase/seed.sql:17-23` and `make db-seed` (`Makefile:151-154`) pull `00_functions.sql`, `gen_all_workouts.sql`, and `gen_training_plans.sql`. The per-category `gen_<category>.sql` files are written but never sourced, so editing one has no effect on a seeded database.
- **Reseeding severs every historical result from its workout.** `gen_all_workouts.sql` opens with `delete from public.workouts where author_id is null` (`build-seeds.ts:513-514`) and `workout_results.workout_id` is `on delete set null` (`supabase/migrations/003_results.sql:4`). The re-insert reuses the same UUIDs but nothing re-links, so `make db-seed`/`db-reseed` permanently orphans past results — despite `Makefile:36` advertising db-reseed as "preserve results + FTP history".
- **`packages/shared/workouts/_spec.md` is stale — don't write YAML from it.** It shows `type: warmup` and `hr_zone:` on flat segments (`:16`, `:20`, `:27`, `:34`), but the schema sets `additionalProperties: false` and defines neither. `type: interval` is the only surviving `type`. Trust `packages/shared/schemas/workout-definition.schema.json` and the `rowing-coach` skill.

## This app has shipped

Releases through 0.16.x are live on the Play Store alpha track (`apps/mobile/CHANGELOG.md`, `.github/workflows/release-please.yml:125-133`). On-device data and existing rows are real; the Drift `onUpgrade` branches are load-bearing, not scaffolding.

Commit type drives that deploy: release-please turns a Conventional Commit on `main` into a version bump, and the resulting release builds an AAB and uploads it automatically (`release-please.yml:125-133`). `feat:` → minor, `fix:` → patch, `refactor:`/`chore:` → no release. Restyling or repositioning an existing feature is `fix:` or `refactor:`, not `feat:`.

## Android build

- **A release build silently falls back to debug signing.** `apps/mobile/android/app/build.gradle.kts:52-56` selects `signingConfigs.getByName("debug")` whenever `apps/mobile/android/key.properties` is absent, so `make apk` / `make release` emit an artifact that looks fine and the Play Store rejects. Confirm `key.properties` exists before trusting a release build.
- **Debug and Play Store installs can't update across each other** (different certificates). Testers must uninstall the debug build first; `apps/mobile/lib/widgets/debug_build_banner.dart` is the in-app reminder.
- **`make install` / `apk` / `release` read secrets from `apps/mobile/.env`** via `-include` at `Makefile:4`. A missing file is not an error — make substitutes empty strings into every `--dart-define`, producing an app that builds cleanly and points at nothing.
- Android only; no tracked `ios/` directory.

## Web app

- **shadcn here is `base-nova` style on Base UI, not Radix** (`apps/web/components.json:3`, plus `@base-ui/react` imports across `apps/web/src/components/ui/`). Snippets from the usual shadcn/Radix docs won't drop in; add components with `npx shadcn@latest add <component>` so the registry resolves the right primitives.
- **`apps/web/.git` is a stale nested repository.** The outer repo tracks `apps/web/**` itself, so any `git` command run from inside `apps/web` talks to the wrong repo — anchor with `git -C <repo-root>`.
- **`cn` is defined twice.** `apps/web/src/lib/utils.ts:4-6` (a file) and `apps/web/src/lib/utils/cn.ts:4-6` (inside the directory of the same name) are byte-equivalent. A bare `@/lib/utils` resolves to the *file*, and `components.json:17` points shadcn's `utils` alias there, so `npx shadcn add` keeps writing to it while most app code imports `@/lib/utils/cn`. Don't add a third.
- **Middleware refreshes the session; it does not guard routes.** `apps/web/src/middleware.ts:36-38` calls `getUser()` and returns unconditionally — there is no redirect. Every protected route calls `requireAuth()` itself (`app/profile/page.tsx:7`, `app/history/page.tsx:12`, `app/admin/layout.tsx:6`). A new route that assumes middleware protects it ships an auth hole.
- **The empty `catch` around cookie writes in `apps/web/src/lib/supabase/server.ts:30-33` is deliberate** — Server Components cannot set cookies, and middleware is what actually persists the refresh. Removing it breaks every Server Component read. To *set* auth state you need a Route Handler or Server Action (`app/auth/callback/route.ts` is the pattern).
- **`expandSegments` in `apps/web/src/lib/utils/workout.ts:52-54` is an identity function** kept for API compatibility — segments are already flat in the DB. The real expander is `expandSegments` in `scripts/build-seeds.ts`, which runs at build time only. Same name, entirely different behaviour.
- **The anon key is named "publishable" everywhere** — `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` on web (`apps/web/src/middleware.ts:9`), `SUPABASE_PUBLISHABLE_KEY` as a dart-define on mobile (`Makefile:105`). There is no `ANON_KEY` variable; reaching for that name gets you `undefined`.
- **`createSupabaseAdmin()` is server-only** (`apps/web/src/lib/supabase/admin.ts:3-10`) — it reads `SUPABASE_SERVICE_ROLE_KEY`, which has no `NEXT_PUBLIC_` prefix and therefore does not exist in the browser bundle. Import it from route handlers and server components only. Admin identity is an env allowlist, not a DB role (`:12-19`).
- Tailwind 4, CSS-first: no `tailwind.config.js`, and `components.json:7` leaves the config path empty on purpose. `npm run check` is `tsc --noEmit`.

## Style

Dark theme on both platforms — rowers train in gyms and garages, and no light variant exists to fall back on. Otherwise write code that reads like the code around it: match the surrounding file's naming, comment density, and idioms rather than importing conventions from elsewhere. Mobile is on Riverpod 3 and go_router 17 (`apps/mobile/pubspec.yaml`), both far enough ahead of most published examples that copied snippets usually need adapting.
