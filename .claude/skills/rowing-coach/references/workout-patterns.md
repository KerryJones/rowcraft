# Workout Patterns

Canonical structures keyed by intent. Each pattern shows warmup / main set / cooldown as YAML-ready segments. Every rest interval respects the 3:00 cap.

Use the closest-existing reference workout as a structural model, then adjust durations and reps for the specific need.

## Base Steady (Aerobic Build)

**Intent:** Aerobic base development. Should feel conversational. Volume over intensity.

```yaml
segments:
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
  - duration: "30:00"   # adjust 20:00–60:00
    intensity: 70%
    stroke_rate: 22
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/zone2-aerobic/steady-state-40.yaml`

**Variants:**
- Long steady: extend main to 45:00–60:00
- Stroke-rate ladder: split main into 10:00 at 20 spm + 10:00 at 22 spm + 10:00 at 24 spm (all 70% intensity)

## Tempo / Sweet Spot

**Intent:** Sustained sub-threshold work. Less common in rowing plans than threshold work, but useful for race-prep-adjacent training.

```yaml
segments:
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
  - type: interval
    reps: 3
    work:
      duration: "10:00"
      intensity: 83%
      stroke_rate: 24
    rest:
      duration: "3:00"
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/zone3-tempo/tempo-3x10.yaml`

## FTP Threshold

**Intent:** Lactate-threshold development. The bread and butter of FTP-building plans.

```yaml
segments:
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
  - type: interval
    reps: 2
    work:
      duration: "12:00"    # adjust 8:00–20:00
      intensity: 95%
      stroke_rate: 26
    rest:
      duration: "3:00"     # MUST be ≤3:00
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/ftp-builder/wk5-threshold.yaml`.

**Progression options:**
- Add a rep: 2×12 → 3×12
- Extend work: 2×12 → 2×15
- Drop rest from 3:00 to 2:30 to increase density

## VO2max — Short Intervals

**Intent:** Maximal oxygen utilization. High stress, requires recovery.

```yaml
segments:
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
  - type: interval
    reps: 6
    work:
      duration: "2:00"
      intensity: 112%
      stroke_rate: 30
    rest:
      duration: "2:00"
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/zone5-vo2max/2-minute-hammers.yaml`

## VO2max — Long Intervals

**Intent:** Longer time-at-VO2max. Higher accumulation, fewer reps.

```yaml
segments:
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
  - type: interval
    reps: 4
    work:
      duration: "3:00"
      intensity: 112%
      stroke_rate: 30
    rest:
      duration: "3:00"
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/zone5-vo2max/3-minute-efforts.yaml`

## 2K Race Pace Simulation

**Intent:** Specific preparation for 2K racing. Race-pace under fatigue.

```yaml
segments:
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
  - type: interval
    reps: 3
    work:
      duration: "500m"     # or 1000m, 1500m for different specificity
      intensity: 112%
      stroke_rate: 30
    rest:
      duration: "3:00"
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/2k-race-prep/wk2-race-pace-6x500m.yaml`

**Variants:**
- 4×500m at race pace, 3:00 rest (intro)
- 3×1000m at race pace, 3:00 rest (build)
- 2×1500m at race pace, 3:00 rest (peak)

## Ladder (Ascending or Descending)

**Intent:** Variable-distance / variable-time work. Tests pacing across multiple efforts.

Note: ladders use flat segments (one segment per piece + one segment per rest) rather than interval blocks, because each rep has a different duration.

```yaml
segments:
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
  - duration: "1:00"
    intensity: 95%
    stroke_rate: 26
  - duration: "1:00"      # rest — no intensity, but ≤3:00
  - duration: "2:00"
    intensity: 95%
    stroke_rate: 26
  - duration: "2:00"      # rest, ≤3:00 — note: 2:00 is fine
  - duration: "3:00"
    intensity: 95%
    stroke_rate: 26
  - duration: "3:00"      # rest at cap
  - duration: "4:00"
    intensity: 95%
    stroke_rate: 26
  - duration: "3:00"      # rest capped at 3:00 (work was 4:00)
  - duration: "5:00"
    intensity: 95%
    stroke_rate: 26
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/wods/ascending-ladder.yaml`.

**Important:** Ladder rests don't have to equal the preceding work duration. The classic "rest = work" pattern breaks at 4:00+ work pieces. For longer pieces, hold rest at 3:00.

## Race-Pace Taper / Openers

**Intent:** Short sharp work in the week before a test or race. Maintain intensity, reduce volume.

```yaml
segments:
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
  - type: interval
    reps: 4
    work:
      duration: "1:30"
      intensity: 112%
      stroke_rate: 30
    rest:
      duration: "3:00"
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/2k-race-prep/wk4-openers.yaml`.

## Recovery Row

**Intent:** Active recovery. Genuinely easy. Used the day after a hard session.

```yaml
segments:
  - duration: "3:00"
    intensity: 60%
    stroke_rate: 20
  - duration: "20:00"    # adjust 20–30 min
    intensity: 55%
    stroke_rate: 20
  - duration: "3:00"
    intensity: 60%
    stroke_rate: 20
```

The main set runs at 55% (intensity floor) while warmup/cooldown bookends sit at 60% per the Hard Constraint rule.

**Closest reference:** `packages/shared/workouts/zone1-recovery/active-recovery-30.yaml`

The warmup/cooldown segments still apply: the Hard Constraint has no recovery-workout exception. A recovery row that is one giant Z1 segment with no bookends fails the workout-shape check.

## Benchmark Tests

**Intent:** Measure fitness. Athletes choose their own test cadence (no requirement to bookend plans).

### 2K Test

```yaml
segments:
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
  - duration: "2000m"
    intensity: 110%      # all-out — the athlete pushes; intensity is just a target reference
    stroke_rate: 32
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/tests/2k.yaml`

### 20-Minute FTP Test

```yaml
segments:
  - duration: "10:00"
    intensity: 60%
    stroke_rate: 20
  - duration: "5:00"
    intensity: 80%
    stroke_rate: 22
  - duration: "20:00"
    intensity: 100%       # all-out for 20 min
    stroke_rate: 28
  - duration: "5:00"
    intensity: 60%
    stroke_rate: 20
```

**Closest reference:** `packages/shared/workouts/tests/20-minute-ftp-test.yaml`
