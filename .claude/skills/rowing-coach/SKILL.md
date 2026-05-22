---
name: rowing-coach
description: Authoring assistant for RowCraft workout and training plan YAML. Generates and reviews files in packages/shared/workouts/ and packages/shared/plans/, enforcing schema, the PM5 3:00 rest cap, and rowing-physiology rules. Use when creating or editing a workout or plan.
paths:
  - "packages/shared/workouts/**/*.yaml"
  - "packages/shared/plans/*.yaml"
---

## What This Skill Is

Authoring assistant for engineers (and AI agents) writing RowCraft seed data YAML. It produces or reviews:
- Workout files in `packages/shared/workouts/<category>/<slug>.yaml`
- Training plan files in `packages/shared/plans/<slug>.yaml`

Output must validate against `packages/shared/schemas/workout-definition.schema.json` and survive `make build-seeds`. Coaching-science knowledge enters only insofar as it informs YAML decisions — coaches are citations that back rules, not authority figures dispensing advice.

**Not for:** athletes seeking workout prescriptions, technique coaching, race-day pacing, or anything related to nutrition.

## Hard Constraints (non-negotiable)

| Constraint | Value | Source / Why |
|---|---|---|
| **Max rest duration** | **3:00** (180s) | PM5 inactivity timeout is 4:00 during a programmed workout. Above the timeout, the PM5 blanks the screen, BLE notifications stop, RowCraft loses tracking. 3:00 leaves a 1-minute safety margin. ([Concept2 PM5 docs](https://www.concept2.com/support/monitors/pm5/how-to-use)) |
| **Intensity range** | 55–200% of FTP | Schema-parser caps at 200%. Below 55% is sub-recovery and physiologically meaningless. |
| **Stroke rate range** | 10–50 spm | Schema-enforced. |
| **Reps per interval block** | 1–50 | Schema-enforced. |
| **Duration formats** | `M:SS` (mins:secs), `Nm` (distance), `Ncal` (calories), bare seconds | Schema-enforced. Mins can be 1–3 digits. |
| **Tags** | Lowercase alphanumeric + hyphen, 1–10 per workout | Schema-enforced. |
| **Warmup** | ≥3 min, intensity 60%, spm 20 | Every workout. The first segment. |
| **Cooldown** | ≥3 min, intensity 60%, spm 20 | Every workout. The last segment. |
| **No `additionalProperties`** | — | Schema disallows unknown fields. Adding a field that isn't in the schema breaks the build. |

The 3:00 rest cap is the most important new rule and the immediate reason this skill exists. If physiology demands rest >3:00 (rare — see Work:Rest Ratio table), split the workout into two separate workouts or replace the rest with a low-intensity active-rest segment (e.g., 3:00 at 60% intensity, 20 spm).

## Methodology Sources

Each name maps to one or more YAML-decisions the skill makes. Full citations with URLs in `references/methodologies.md`. Never name a coach in skill output without a real, sourced citation.

- **Stephen Seiler — 80/20 polarized distribution.** Backs the intensity mix when designing a plan: ~80% time at easy intensity (≤75%), ~20% at hard intensity (≥92%), with minimal time in the 83–92% "gray zone."
- **Tudor Bompa — classical periodization.** Backs plan structure: 4–6 week mesocycles, deload week after each.
- **Vladimir Issurin — block periodization.** Backs short-plan structure: 2–4 week concentrated blocks for one adaptation.
- **Joe Friel — ability-based periodization.** Backs phase progression: base → build → specialty.
- **Jack Daniels — VDOT zone math.** Backs FTP-anchored zone targeting (a single fitness number drives all paces).
- **Eddie Fletcher — "go slow more, go fast less."** Backs aerobic volume emphasis in beginner/intermediate plans.
- **Mike Caviston — Wolverine Plan intensity structure.** Backs 2K-specific work blocks.
- **Pete Marston — Pete Plan continuous progression.** Backs beginner plan structure (3 sessions/week, weekly progression, conservative pacing). The Pete Plan deliberately skips explicit deload weeks — continuous progression is the model, so it is the documented exception to the "deload per 4-week mesocycle" rule.
- **Xeno Müller — technique-led training.** Backs explicit `stroke_rate` on every segment and lower-rate steady work for advanced athletes.
- **Hal Higdon — accessible plan structure.** Backs single-role-per-session simplicity in beginner / return-to-rowing plans.
- **Pete Pfitzinger — threshold-anchored periodization.** Backs the non-default threshold-heavy distribution option for advanced athletes targeting LT improvement.
- **Concept2 official UT2/UT1/AT/TR/AN bands.** Backs the zone table below.
- **Comparable apps (Asensei, EXR, ErgZone, Dark Horse).** Pattern references for plan shape — not authoritative, just market-validated.

## Intensity Targets (canonical for YAML)

**Intensity is the source of truth in YAML.** Match existing RowCraft convention. Use exact midpoint values, never ranges.

| Workout category | Intensity | SPM | Use For |
|---|---|---|---|
| Recovery / warmup / cooldown | `60%` | 20 | First and last segment of every workout |
| Aerobic base (steady) | `70%` | 22 | Long steady-state aerobic work |
| Tempo (sweet spot) | `83%` | 24 | Sustained sub-threshold efforts |
| Threshold | `95%` | 26 | Threshold interval work — FTP-building |
| VO2max / race pace | `112%` | 30 | Short hard intervals, 2K simulation |
| Sprints | `120%`+ | 32+ | Sub-1-minute all-out efforts |

The build-seeds pipeline derives `target_hr_zone` (1–5) from intensity via `intensityToHrZone()` in `scripts/build-seeds.ts`. The app renders zone labels via `HrZoneLegend`, which is **system-aware**: the user's profile `zone_system` toggles between `'standard'` (Z1/Aerobic, Z2/Tempo, Z3/Threshold, Z4/VO2max, Z5/Max) and `'rowing'` (UT2/Base Aerobic, UT1/Aerobic Power, AT/Threshold, TR/VO2max, AN/Anaerobic) — both share identical %HR boundaries.

**Implication for YAML:** never reference Z1–Z5 or UT2/UT1/AT/TR/AN labels in `description` or `notes` fields — they collide across systems and create ambiguity. Use descriptive terms ("threshold," "aerobic base," "VO2max," "recovery") plus the intensity percentage.

## Schema Reference

Workout files validate against `packages/shared/schemas/workout-definition.schema.json` (`additionalProperties: false` everywhere — no extra fields). Plan files have no JSON schema currently; they're validated only by `make build-seeds` parsing in `scripts/build-seeds.ts`.

### Workout

```yaml
id: <uuid>                                 # Stable. Never change once published.
title: "Pete Plan Wk3 Wed — 4x1000m"       # 1–200 chars
description: "Week 3 Wednesday: 4x1000m intervals with 3-minute rest."  # 1–2000 chars
difficulty: beginner | intermediate | advanced
tags: [pete-plan, intervals, speed, week-3] # lowercase-alphanumeric-hyphen, 1–10
segments:
  # Warmup (required, ≥3 min at 60%, 20 spm)
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20

  # Interval block (work + rest, repeated)
  - type: interval
    reps: 4                                # 1–50
    work:
      duration: "1000m"                    # M:SS | Nm | Ncal | bare seconds
      intensity: 95%
      stroke_rate: 26
    rest:
      duration: "3:00"                     # MUST be ≤3:00

  # Cooldown (required, ≥3 min at 60%, 20 spm)
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

Flat segments support: `duration` (required), `intensity`, `target_watts`, `stroke_rate`, `messages`. Interval blocks support: `type: interval` (required), `reps` (required, 1–50), `work` (required, target fields), `rest` (optional, duration only). The build pipeline expands intervals to a flat list at compile time (rest is omitted after the last rep).

### Plan

```yaml
id: <uuid>
slug: <kebab-case>                          # url-friendly, unique across plans
title: "FTP Builder"
description: "Six weeks of structured threshold and VO2max work to raise Functional Threshold Pace. Run an FTP test before and after."
difficulty: intermediate
sessions_per_week: 3
tags: [ftp-builder, intermediate, threshold]
weeks:
  - title: "Foundation"
    sessions:
      - day_label: "Day 1"
        workout_id: "<uuid of an existing workout>"
        notes: "Threshold introduction — ease into the zones"
      - day_label: "Day 2"
        workout_id: "..."
        notes: "..."
      - day_label: "Day 3"
        workout_id: "..."
        notes: "..."
  - title: "Build Phase 1"
    sessions: [...]
  # ... one entry per week
```

`weeks.length` becomes `duration_weeks` at build time. Each session points to a workout by UUID; the workout must already exist (or be created in the same PR). Plans use their own UUID family — e.g., FTP Builder uses `e1000000-0000-0000-<weekNum>-<sessionNum>` for its workouts. New plans pick their own family prefix.

## Workflow A — Author a Single Workout

1. **Clarify intent** (one sentence): adaptation target (threshold / VO2max / base / race-sim / recovery), total duration, athlete level.
2. **Select a pattern** from `references/workout-patterns.md` matching the intent.
3. **Build the spec as a table**:

   | Segment | Type | Duration | Intensity | SPM | Rest |
   |---|---|---|---|---|---|
   | Warmup | flat | 5:00 | 60% | 20 | — |
   | Main set | interval × 4 | 1000m | 95% | 26 | 3:00 |
   | Cooldown | flat | 5:00 | 60% | 20 | — |

4. **Validate against Hard Constraints** — every rest ≤3:00, warmup/cooldown present and ≥3min at 60%/20 spm, intensity in range, spm in range.
5. **Show the spec to the user.** On approval, emit YAML with a fresh UUID, schema-valid tags, and a suggested file path (e.g., `packages/shared/workouts/<category>/<slug>.yaml`).

## Workflow B — Author a Multi-Week Plan

1. **Clarify**: goal (with metric), weeks, sessions/week, athlete level.
2. **Pick the periodization model**:
   - **4 weeks** → single block (Issurin) — one adaptation in concentrated form.
   - **6–8 weeks** → classical base → build → peak (Bompa / Friel) — see `references/periodization-templates.md`.
   - **12–16 weeks** → multi-mesocycle with mid-plan test (TrainerRoad pattern).
   - **Beginner returning** → continuous weekly progression (Pete Plan model).
3. **Set intensity distribution** — default 80/20 polarized (Seiler). Threshold-heavy only with explicit justification.
4. **Lay out the week-by-week spec as a table**:

   | Week | Phase | Day 1 | Day 2 | Day 3 | Volume | Notes |
   |---|---|---|---|---|---|---|
   | 1 | Foundation | Threshold intro 2×8min at 95% | Steady 30min at 70% | Recovery 20min at 60% | 64 min | Open with FTP test |
   | … | | | | | | |

5. **Apply the Quality Checklist** before showing the user.
6. **Show the spec.** On approval, emit:
   - One plan YAML at `packages/shared/plans/<slug>.yaml`
   - N custom workout YAMLs at `packages/shared/workouts/<slug>/wk<N>-<focus>.yaml`
   - Workouts inside a plan are **always custom** to that plan (matches `ftp-builder/`, `pete-plan/`, etc. — no reuse from the zone library).

## Workflow C — Review an Existing Workout or Plan

1. **Schema check** — required fields, additionalProperties violations, value-range bounds.
2. **Hard-constraints check** — every rest ≤3:00, warmup ≥3min at 60%/20 spm, cooldown ≥3min at 60%/20 spm, intensity 55–200%, spm 10–50.
3. **Physiological check** — work:rest ratios reasonable (see table below), stroke rate matches intensity (e.g., not 30 spm at 60% intensity), zone progression coherent.
4. **Periodization check (plans only)** — week-over-week volume change ≤10%, deload present per mesocycle (race-week taper counts as deload for race-prep plans per Friel), sessions_per_week matches the count of non-optional sessions per week.
5. **Report findings as a punch list**, severity-labeled: **blocker** (schema or PM5 violation), **warning** (physiological concern), **suggestion** (improvement).

## Work:Rest Ratio Quick Reference

| Intent | Work | Rest | Ratio | Note |
|---|---|---|---|---|
| Threshold (95% intensity) | 8–20 min | 2–3 min | 4:1 to 6:1 | Cap rest at 3:00 (PM5) |
| VO2max (112% intensity) | 2–4 min | 2–3 min | ~1:1 | Rest ≈ work, capped at 3:00 |
| Race-pace (112% intensity) | 500–1500m | 2:30–3:00 | varies | Cap at 3:00 |
| Sprints (120%+ intensity) | 30–60s | 1–2 min | 1:2 | Well under cap |
| Recovery between distance pieces | — | up to 3:00 | — | Never exceed |

If physiology calls for rest >3:00, do **not** write a longer rest. Instead either: (a) split the work into two separate workouts, or (b) replace the rest with an active-rest segment at 60% intensity, 20 spm (which is rowing, not rest — the PM5 stays awake).

## Quality Checklist (apply before emitting YAML)

```
Schema
[ ] All required fields present
[ ] UUID matches the schema pattern; unique within the repo
[ ] Tags lowercase alphanumeric + hyphen, 1–10
[ ] Duration formats valid (M:SS / Nm / Ncal / bare seconds)
[ ] Intensity values in 55–200%
[ ] Stroke rate in 10–50
[ ] No extra fields (additionalProperties: false)

PM5 Safety (blockers)
[ ] No interval rest > 3:00
[ ] No flat rest segment > 3:00

Workout shape
[ ] Warmup ≥3 min at 60%, 20 spm (first segment)
[ ] Cooldown ≥3 min at 60%, 20 spm (last segment)
[ ] Stroke rate matches intensity (low spm at low intensity, high at high)
[ ] Workout has a clear single intent (one adaptation targeted)

Plan shape (plans only)
[ ] Volume change week-over-week ≤10%
[ ] At least one deload week per 4-week mesocycle (~30–50% volume drop); race-week taper counts as the deload for race-prep plans (Friel)
[ ] Intensity distribution honors 80/20 unless explicitly justified
[ ] Every session.workout_id points to a workout that exists in the same PR
[ ] sessions_per_week equals the count of non-optional sessions per week. Sessions labeled `(Optional)` in `day_label` count as bonus and do not increment the declared value.

Citations
[ ] Every coach / framework named in output has a URL in references/methodologies.md
[ ] No fabricated authority
```

## Anti-Patterns (✗ explicitly flag)

- ✗ Rest interval > 3:00 (PM5 timeout — **blocker**)
- ✗ Stroke rate mismatched to intensity (e.g., 30 spm at 60%)
- ✗ Workout without warmup or cooldown
- ✗ Workout without a clear single intent
- ✗ Plan with no deload per 4-week mesocycle (race-week taper counts as deload for race-prep plans)
- ✗ Volume ramp >10% week-over-week
- ✗ Threshold-heavy block with no aerobic base phase first
- ✗ Intensity ranges like "90–95%" in YAML — use a single midpoint
- ✗ Watts as the primary metric in `description` or `notes` — rowers use pace (m:ss/500m)
- ✗ Naming a coach without a real URL in `references/methodologies.md`
- ✗ Any nutrition, hydration, fueling, weight-loss, or supplement content
- ✗ Backward-compat code or migration shims — RowCraft is pre-launch
- ✗ Editing generated SQL in `supabase/seeds/generated/` directly — YAML is source of truth
- ✗ Reusing zone-library workouts inside a plan — plans get their own custom workouts (matches existing convention)

## Tests vs. Rest

The `tests/` workouts (`just-row.yaml` 120:00, `20-minute-ftp-test.yaml` 20:00, `4min.yaml` 4:00) have long flat segments that are the *workout itself*, not rest — they are not 3:00-cap violations.

## Remember

- Every workout has a single clear intent.
- Every rest ≤ 3:00. No exceptions. Use active-rest at 60% if you need more recovery.
- Pace, not watts.
- Exact midpoint intensities, never ranges.
- Plans always get their own custom workouts.
- Cite real coaches with real URLs; never fabricate.
- 80/20 polarized unless you can defend the deviation.
- Schema validates or it doesn't ship.
- No nutrition content, ever.
