# RowCraft

Monorepo: Flutter mobile + Next.js web + Supabase backend for structured rowing workouts on Concept2 PM5.

## Rules

### Ownership & Quality
- You own this entire codebase. A failing test is always your bug — never dismiss as pre-existing.
- **Write tests before or alongside features** — not comprehensive TDD, but cover the key behaviors: happy path, error paths, and edge cases that would catch regressions. If a bug is being fixed, write a test that reproduces it first.
- Planning sessions use a separate git worktree (`isolation: "worktree"`).
- **Sync worktree with main before starting work** — worktrees don't auto-update when main advances. At the start of a session, run `git log --oneline HEAD..main` to check for new commits. If behind, merge main before reading or editing any files. Skipping this causes regressions by overwriting work done in other worktrees.
- Run code review agent in a loop until clean before presenting code as done.
- **Resolve TODOs during planning** — when exploring code for a task, scan for existing TODOs in the files you touch. If a TODO is achievable within the current scope, include it in the plan and do it. Don't leave TODOs behind in new code.
- Always run checks before done: `flutter analyze` (mobile), `npm run check` (web).
- **Test builds, not just analyze** — when changing dependencies, Android config, or native code, run `flutter build apk --debug` to catch Gradle/Kotlin compilation errors that `flutter analyze` misses.

### Pre-launch App
- **No legacy/backward-compat code** — this app has not shipped. Never write migration shims, legacy expansion, or backward-compat wrappers without asking first. If you think old data needs handling, ask.

### Research Before Guessing
- **Never fabricate or guess external information** — if a task references external products, APIs, UI patterns, or industry standards, research them first (WebSearch, WebFetch, docs). Guessing and presenting it as informed analysis is a critical failure, not a minor shortcut.

### Coding Principles
**CONSISTENT > CANONICAL > SIMPLE**
1. **Consistent** — match existing patterns in the codebase first
2. **Canonical** — use the standard/documented approach for the library/framework
3. **Simple** — prefer the simplest solution that works
- **Always prefer the best action over the low-effort action** — don't take shortcuts or propose easier alternatives when the right solution requires more work.

### Dependencies
- **Always upgrade, never downgrade** — when a dependency conflict or version mismatch occurs, upgrade to the latest stable version. Never downgrade a package or pin to an older version unless there is no other option, and then only with explicit user permission.

### Code Style
- **Dart**: Dart 3.3+, type hints, immutable models with `copyWith`, Riverpod for state
- **TypeScript**: Strict mode, Next.js App Router (Server Components default, `'use client'` for interactive)
- **SQL**: Lowercase keywords, snake_case columns, always add indexes on foreign keys

### Communication
- **No sycophancy** — don't soften, hedge, or flatter. State what you think directly.
- **Push back when appropriate** — disagree when you have good reason. Don't treat every user statement as a directive.
- **Take words at face value** — respond to what the user actually said, not what you think they meant. Don't "read between the lines" or reinterpret requests. If the user asks you to do X, do X — don't do Y because you think that's what they really wanted.
- **Never double down on claims you can't verify** — if corrected, accept it. Don't defend a position by fabricating supporting claims (e.g. "X works like Y" when you don't actually know how Y works). One wrong claim is a mistake; stacking more unverified claims to defend it is a pattern failure.

### Design Rules
- **Dark theme only** — both platforms. Rowers are in gyms/garages.
- **Split times in tenths of seconds** — 2:00/500m = 1200. Storage is tenths; display is `M:SS` (no decimal).
- **PM5 data via BLE notifications only** — never use BLE reads (returns junk).
- Segment colors must match across mobile and web: work=blue, rest=gray, warmup=green, cooldown=yellow.
- **UX self-review before presenting UI work** — for every visual container, ask: "What mental model does this layout create? Would a first-time user interpret this the same way the code intends it?" Check Gestalt grouping: elements in the same container are perceived as one entity.

### Tool Usage
- Prefer Claude Code tools (Read, Edit, Write, Glob, Grep) over Bash equivalents.
- Allowlisted Bash: `make`, `git`, `flutter`, `npm`, `dart`, `npx`, `supabase`.
- **No compound Bash commands** (pipes, `cd && ...`, chained commands) — they always prompt. Use `-C` flags (`git -C path`), `--prefix` (`npm --prefix path`), or separate Bash calls instead.
- **No git commits/pushes without explicit user permission.** Read-only git (`diff`, `status`, `log`) is fine.
- **No Claude attribution in commit messages.** Never add `Co-Authored-By` or similar AI credit lines.
- **Commit messages as plain text** — no quotes, backticks, or code fences when presenting a commit message.

### Memory Discipline
- Do NOT save architecture, file paths, code patterns, or project structure to MEMORY.md.
- MEMORY.md is only for user preferences and feedback.
- Architecture and reference docs belong in `docs/` if they need to be persisted.
- Keep CLAUDE.md under 100 lines — behavioral rules only, not reference content.

## Build & Test

### Mobile
```
cd apps/mobile
flutter pub get
dart run build_runner build
flutter test
flutter analyze
```

### Web
```
cd apps/web
npm install
npm run check
npx vitest
```

### Supabase
```
supabase start
supabase db reset
```

## Reference Docs

Detailed docs live in `docs/`. **Do not put reference content in CLAUDE.md** — this file is for behavioral rules only.

| File | Contents |
|------|----------|
| `docs/architecture.md` | System overview, data flows, tech stack, design decisions |
| `docs/database.md` | Schema, migrations, tables, RLS policies |
| `docs/key-files.md` | File map with descriptions (web + mobile + shared) |

### When to read
- **Starting a task**: Read the doc(s) relevant to the subsystem you're about to touch.
- **Don't pre-load all docs** — only read what's needed for the current task.

### When to update
- After adding/changing a subsystem, update the relevant `docs/` file — not CLAUDE.md.
- After adding/changing a behavioral rule or convention, update CLAUDE.md — not `docs/`.
