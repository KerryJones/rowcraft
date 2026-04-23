# RowCraft

Monorepo: Flutter mobile + Next.js web + Supabase backend for structured rowing workouts on Concept2 PM5.

## Rules

### Before Presenting Work as Done
1. Run checks: `flutter analyze` (mobile), `npm run check` (web).
2. If dependencies, Android config, or native code changed: `flutter build apk --debug`.
3. Run code review agent in a loop until clean.
4. If generated files changed, tell the user what commands to run locally.

### Ownership & Quality
- You own this entire codebase. A failing test is always your bug — never dismiss as pre-existing.
- **Write tests before or alongside features** — happy path, error paths, and edge cases. If fixing a bug, write a reproducing test first.
- Planning sessions use a separate git worktree (`isolation: "worktree"`).
- **Sync worktree with main before starting work** — run `git log --oneline HEAD..main` at session start. If behind, merge main before reading or editing files.
- **Resolve TODOs during planning** — scan for existing TODOs in files you touch. If achievable in scope, do it. Don't leave TODOs in new code.

### Generated Files
- **YAML is the source of truth for workouts** — never edit `gen_*.sql` or `gen_all_workouts.sql` directly. Edit YAML in `packages/shared/workouts/`, then run `npx tsx scripts/build-seeds.ts`.
- **Never edit any generated file directly** — find the source and edit that instead.

### Pre-launch App
- **No legacy/backward-compat code** — this app has not shipped. Never write migration shims, legacy expansion, or backward-compat wrappers without asking first. If you think old data needs handling, ask.

### Research Before Guessing
- **Never fabricate or guess external information** — if a task references external products, APIs, UI patterns, or industry standards, research them first (WebSearch, WebFetch, docs). Guessing and presenting it as informed analysis is a critical failure, not a minor shortcut.

### Consistency is #1
**Consistency is the highest-priority principle across everything** — code patterns, UI design, interactions, naming, spacing, button styles, error handling, dialog layouts. When adding or changing anything, find the existing pattern and match it exactly. Inconsistency is a bug. If you build a new dialog, find the most recent dialog and match its structure. If you style a button, find the established button style and use it. This applies universally, not just to code.

### Coding Principles
**CONSISTENT > CANONICAL > SIMPLE**
1. **Consistent** — match existing patterns in the codebase first
2. **Canonical** — use the standard/documented approach for the library/framework
3. **Simple** — prefer the simplest solution that works
- **Always prefer the best action over the low-effort action** — don't take shortcuts or propose easier alternatives when the right solution requires more work.

### Dependencies
- **Always upgrade, never downgrade** — when a dependency conflict or version mismatch occurs, upgrade to the latest stable version. Never downgrade a package or pin to an older version unless there is no other option, and then only with explicit user permission.
- **Prefer stable libraries over rolling your own** — for solved problems (string truncation, date formatting, deep equality, debouncing, URL parsing, etc.), use a well-maintained library rather than writing it inline. Hand-rolled utilities accumulate bugs and edge cases that battle-tested libraries have already fixed.

### Code Style
- **Dart**: Dart 3.3+, type hints, immutable models with `copyWith`, Riverpod for state
- **TypeScript**: Strict mode, Next.js App Router (Server Components default, `'use client'` for interactive)
- **SQL**: Lowercase keywords, snake_case columns, always add indexes on foreign keys
- **Web UI**: Use shadcn components (`npx shadcn@latest add <component>`) before building custom controls. The web app uses shadcn v4 with base-nova style and Base UI primitives.

### Communication
- **No sycophancy** — don't soften, hedge, or flatter. State what you think directly.
- **Push back when appropriate** — disagree when you have good reason. Don't treat every user statement as a directive.
- **Take words at face value** — respond to what the user actually said, not what you think they meant. Don't "read between the lines" or reinterpret requests. If the user asks you to do X, do X — don't do Y because you think that's what they really wanted.
- **Never double down on claims you can't verify** — if corrected, accept it. Don't defend a position by fabricating supporting claims (e.g. "X works like Y" when you don't actually know how Y works). One wrong claim is a mistake; stacking more unverified claims to defend it is a pattern failure.

### Design Rules
- **Dark theme only** — both platforms. Rowers are in gyms/garages.
- **Split times in tenths of seconds** — 2:00/500m = 1200. Storage is tenths; display is `M:SS` (no decimal).
- **PM5 data via BLE notifications only** — never use BLE reads (returns junk).
- Segment colors from stored `target_hr_zone` (derived from intensity at build/save time). No zone = gray (#6b7280). Z1=green, Z2=blue, Z3=amber, Z4=orange, Z5=red.
- **UX self-review before presenting UI work** — for every visual container, ask: "What mental model does this layout create? Would a first-time user interpret this the same way the code intends it?" Check Gestalt grouping: elements in the same container are perceived as one entity.

### Tool Usage
- Prefer Claude Code tools (Read, Edit, Write, Glob, Grep) over Bash equivalents.
- **In worktree sessions, never use absolute paths that point at the main repo root.** The main repo root (`/Users/kerryjones/code/rowcraft/apps/...`) still exists alongside the worktree (`/Users/kerryjones/code/rowcraft/.claude/worktrees/<name>/apps/...`) and contains an identical tree, so an absolute path written from memory will silently edit the wrong copy — tests and analyze keep passing in the worktree because the worktree files are untouched. Use paths relative to the worktree cwd, or absolute paths anchored at the worktree root.
- Allowlisted Bash: `make`, `git`, `flutter`, `npm`, `dart`, `npx`, `supabase`.
- **No compound Bash commands** (pipes, `cd && ...`, chained commands) — they always prompt. Use `-C` flags (`git -C path`), `--prefix` (`npm --prefix path`), or separate Bash calls instead.
- **No git commits/pushes without explicit user permission.** Read-only git (`diff`, `status`, `log`) is fine.
- **No Claude attribution in commit messages.** Never add `Co-Authored-By` or similar AI credit lines.
- **Commit messages as plain text** — no quotes, backticks, or code fences when presenting a commit message.
- **Conventional Commits** — all commit messages must use the format `type: description`. Types: `feat:` (new feature), `fix:` (bug fix), `refactor:`, `chore:`, `docs:`, `test:`. Use `feat!:` or `fix!:` for breaking changes. release-please uses these prefixes to auto-generate changelogs and version bumps.

### Memory Discipline
- Do NOT save architecture, file paths, code patterns, or project structure to MEMORY.md.
- MEMORY.md is only for user preferences and feedback.
- Architecture and reference docs belong in `docs/` if they need to be persisted.
- Keep CLAUDE.md under 100 lines — behavioral rules only, not reference content.

## Reference Docs

Read the relevant doc before starting a task. Don't pre-load all of them.

| File | Contents |
|------|----------|
| `docs/architecture.md` | System overview, data flows, tech stack |
| `docs/database.md` | Schema, migrations, tables, RLS policies |
| `docs/key-files.md` | File map with descriptions |

After changing a subsystem, update the relevant `docs/` file. After changing a behavioral rule, update CLAUDE.md.
