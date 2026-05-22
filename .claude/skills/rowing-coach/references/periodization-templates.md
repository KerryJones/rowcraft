# Periodization Templates

Concrete week-by-week templates for common plan lengths and goals. Each template specifies phase names, session intent per day, and where to place tests and deloads. Each cell describes the *intent* — the YAML workout is custom-authored per plan to match.

All templates assume 3 sessions / week unless noted. Scale up to 4–5 by adding a second quality day with 48 hr separation, or 6 by rotating quality / distance with strict rest (Pete Plan model).

## 4-Week Single Block (Issurin)

Use when: time-constrained athlete, one specific adaptation, or as a focused phase inside a longer plan.

| Week | Phase | Day 1 | Day 2 | Day 3 | Notes |
|---|---|---|---|---|---|
| 1 | Intro | Test (FTP or 2K) | Easy 30 min at 70% | Intro intervals (low volume of target adaptation) | Open with benchmark |
| 2 | Build | Target work (2× block) | Easy 30–40 min at 70% | Target work (2× block) | Add reps or duration |
| 3 | Peak | Target work (3× block) | Easy 30 min at 70% | Target work (3× block) | Highest volume of target work |
| 4 | Taper + Retest | Light intervals (50% volume) | Easy 20 min at 70% | Test (same as week 1) | Compare to baseline |

## 6-Week Classical (Bompa / Friel) — FTP-Building Example

Use when: intermediate athlete, 6 weeks available, goal is threshold/FTP improvement.

| Week | Phase | Day 1 | Day 2 | Day 3 | Notes |
|---|---|---|---|---|---|
| 1 | Foundation | FTP test (20-min) | Steady 30 min at 70% | Recovery 20 min at 60% | Baseline |
| 2 | Build 1 | Threshold 2×10 min at 95%, 3min rest | Steady 35 min at 70% | Recovery 25 min at 60% | Intro threshold |
| 3 | Build 2 | Threshold 2×12 min at 95%, 3min rest | Steady 40 min at 70% | VO2max 5×3 min at 112%, 3min rest | Add VO2max |
| 4 | Peak 1 | Threshold 3×10 min at 95%, 3min rest | Steady 40 min at 70% | VO2max 6×3 min at 112%, 3min rest | Peak volume |
| 5 | Peak 2 | Threshold 2×15 min at 95%, 3min rest | Steady 30 min at 70% | VO2max 4×4 min at 112%, 3min rest | Highest intensity |
| 6 | Taper + Retest | Light openers 4×500m at 112%, 3min rest | Easy 20 min at 70% | FTP test (same protocol) | Compare to week 1 |

Existing reference: `packages/shared/plans/ftp-builder.yaml` — six weeks, three sessions/week, Foundation→Build×2→Peak×2→Taper.

## 8-Week Classical with Mid-Plan Test

Use when: intermediate–advanced athlete, want to verify progress mid-plan.

| Week | Phase | Day 1 | Day 2 | Day 3 |
|---|---|---|---|---|
| 1 | Foundation | Test | Steady at 70% | Recovery at 60% |
| 2 | Foundation | Threshold (low vol) | Steady at 70% | Recovery at 60% |
| 3 | Build 1 | Threshold (mid vol) | Steady at 70% | VO2max (low vol) |
| 4 | Build 1 | Threshold (high vol) | Steady at 70% | VO2max (mid vol) |
| 5 | Mid-test | Mid-plan test | Easy 30 min at 70% | Easy 20 min at 60% |
| 6 | Peak | Threshold (high vol) | Steady at 70% | VO2max (high vol) |
| 7 | Peak | Race-pace simulation | Steady at 70% | VO2max (high vol) |
| 8 | Taper + Retest | Light openers | Easy 20 min at 70% | Final test |

## 12-Week Full Periodized (TrainerRoad Pattern)

Use when: advanced athlete, long preparation window, want full base-build-specialty.

Three 4-week mesocycles, each ending with a recovery week.

| Mesocycle | Weeks | Phase | Focus |
|---|---|---|---|
| 1: Base | 1–4 | Aerobic base | Mix of recovery sessions at 60% and aerobic sessions at 70%, light threshold introduction. Week 4 = deload. |
| 2: Build | 5–8 | Threshold + VO2max | Heavy threshold work (95%), intro VO2max (112%). Week 8 = deload + mid-test. |
| 3: Specialty | 9–12 | Race-specific | Race-pace simulations, taper. Week 12 = final test. |

Each week within a mesocycle: Day 1 quality (target adaptation), Day 2 long steady, Day 3 secondary quality or recovery.

Existing reference: `packages/shared/plans/2k-12-week.yaml` — 12 weeks, full periodization with two tests.

## 16-Week Race Prep

Use when: advanced athlete prepping for a specific event (e.g., CRASH-B, Indoor Worlds, 2K time trial).

Four 4-week mesocycles:

| Mesocycle | Weeks | Phase |
|---|---|---|
| 1: General Prep | 1–4 | Aerobic base, technique work |
| 2: Specific Prep | 5–8 | Threshold + sub-threshold endurance |
| 3: Race Prep | 9–12 | VO2max + race-pace specifics |
| 4: Peak + Taper | 13–16 | Race simulations, peak then taper to event |

Each mesocycle ends with a deload week. Mid-mesocycle volume peaks should be at weeks 2–3 (mesocycle internal), not week 1 or 4.

## Continuous Progression (Pete Plan Model)

Use when: beginner returning to fitness, time-constrained, no specific event.

No mesocycle structure. Same weekly template, with each week's target slightly harder than the previous.

| Day | Type | Notes |
|---|---|---|
| Day 1 | Distance | Build distance week over week (5K → 5.5K → 6K → …) |
| Day 2 | Intervals (speed) | Set pace conservative until final rep; final rep dictates next week's target |
| Day 3 | Distance / steady | 20–24 min steady at 70% |

Take next week's interval target from this week's final rep. Cap weekly volume increase at ~10%.

Existing reference: `packages/shared/plans/pete-plan.yaml` — six weeks, three sessions/week, continuous progression.

## Return to Rowing

Use when: athlete coming back from a layoff (injury, life event, time off).

| Week | Day 1 | Day 2 | Day 3 |
|---|---|---|---|
| 1 | 15 min at 60%, technique focus | 15 min at 60%, technique focus | 20 min at 60% |
| 2 | 20 min at 70% | 20 min at 70% | 25 min at 70% |
| 3 | 25 min at 70% | 25 min at 70% with strides | 30 min at 70% |
| 4 | 30 min at 70% | Light tempo intro (2×5 min at 83%, 3min active rest at 60%) | 30 min at 70% + test |

Conservative ramp. Volume changes ≤10% week-over-week. No threshold or VO2max work until at least week 4.

Existing reference: `packages/shared/plans/return-to-rowing.yaml`.

## Volume / Intensity Distribution Sanity-Check

For a polarized 80/20 plan, computed across a full mesocycle (not a single week):

- **80% of total time** at easy intensity (60–70%)
- **20% of total time** at hard intensity (95% and above)
- **Sub-threshold "gray zone" time (~83–92%) should be small** — ideally <10%; this is the range Seiler warned about

For a threshold-anchored plan (Pfitzinger pattern), the distribution may run closer to 70/20/10 across easy / threshold-and-just-below / VO2max-and-above. This is a valid choice for advanced athletes targeting lactate-threshold improvement, but it should be a deliberate decision, not the default.

## Deload Week Rules

Every 4-week mesocycle ends with a deload. A deload:

- Reduces total weekly volume by 30–50% vs the preceding peak week
- Replaces any threshold/VO2max work with easy 60–70% work, or a single light "openers" session
- Includes a test if it's the end of a phase

Skipping deloads is the most common periodization error in self-authored plans. Watch for it during plan review.
