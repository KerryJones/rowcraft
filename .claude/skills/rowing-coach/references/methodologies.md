# Methodologies — Citations and YAML Implications

Every coach or framework named in skill output must trace to a real URL here. Never fabricate authority.

## Rowing-Specific Coaches

### Mike Caviston — Wolverine Plan

Coach for Michigan Women's Rowing 2001–2004, kinesiology background. The Wolverine Plan is one of the most cited indoor rowing frameworks for 2K performance — structured intensity bands with precise watt, pace, SPM, duration, and interval controls. Tests-driven, not feel-driven.

**YAML implication:** When designing 2K-specific plans, base the structure on systematic intensity-band progression with frequent benchmarks rather than open-ended progressive overload.

**Source:** [row2k feature interview](https://www.row2k.com/features/391/mike-caviston-training-with-the-wolverine-plan-and-working-with-navy-seals/)

### Eddie Fletcher — Fletcher Sport Science

Sport and exercise physiologist with 20+ years coaching indoor rowing world / British / European champions. Operates a sports science lab. His principle "go slow more, go fast less" is the rowing-physiology basis for polarized training.

**YAML implication:** In beginner / intermediate plans, prioritize aerobic-volume sessions over intense ones. Aim for ~3 easy/long sessions per intense session.

**Sources:**
- [Fletcher Sport Science](https://fletchersportscience.com/)
- [World Rowing — "Go slow more, go fast less"](https://worldrowing.com/2024/02/19/go-slow-more-go-fast-less-indoor-rowing-preparation/)

### Xeno Müller — Elite Rowing Coach

Olympic gold (1996) and silver (2000) in single scull. Coaches via online platform. Emphasizes technique optimization, CO2 tolerance, muscle-fiber recruitment, and proportional mitochondrial adaptation over raw volume.

**YAML implication:** Workouts should specify stroke rate explicitly (technique cue), not just intensity. Plans for advanced athletes can include lower-rate steady work to bias muscle-fiber recruitment.

**Source:** [Elite Rowing Coach](https://elite-rowing-coach.com)

### Pete Marston — The Pete Plan

Designed for athletes with limited time (lunch-hour sessions). Continuous weekly progression rather than periodized blocks. Three session types: speed intervals, endurance intervals, distance work. Conservative pacing except the final interval, which dictates next week's target.

**YAML implication:** Beginner plans for time-constrained athletes should follow a continuous-progression pattern (steady weekly improvement) rather than a base→build→peak periodization. Three sessions / week is the standard.

**Sources:**
- [The Pete Plan](https://thepeteplan.wordpress.com/the-pete-plan/)
- [Pete Plan beginner training](https://thepeteplan.wordpress.com/beginner-training/)

## Institutional / Official

### British Rowing

National governing body. Publishes 8-week structured training plans for indoor rowing covering aerobic fitness, strength maintenance, power, and 2K race prep. Uses periodization with super-compensation principle.

**YAML implication:** 8 weeks is a credible block size for a complete training phase. Plans should explicitly name the phase outcome (e.g., "Foundation," "Build Phase 1," "Peak").

**Sources:**
- [British Rowing Indoor Plans](https://www.britishrowing.org/indoor-rowing/go-row-indoor/how-to-indoor-row/british-rowing-training-plans/)
- [British Rowing Plus — Designing Elite Programs](https://plus.britishrowing.org/2023/01/16/designing-an-elite-rowing-training-programme-overview/)

### Concept2 — Official PM5 / Training Resources

Maker of the rower and the PM5. The pace chart, training-band documentation (UT2 / UT1 / AT / TR / AN), and 2K test protocol are the canonical references for any erg-specific decision.

**YAML implication:** Concept2 documentation is the primary citation for any erg-specific decision. The PM5 inactivity timeout drives the 3:00 rest cap (see SKILL.md Hard Constraints for the rule).

**Sources:**
- [Understanding the PM5](https://www.concept2.com/training/articles/understanding-pm5)
- [Concept2 Training HR Range](https://www.concept2.com/indoor-rowers/training/tips-and-general-info/training-heart-rate-range)
- [How to Find Your 2K Race Pace](https://www.concept2.com/training/articles/how-to-find-your-2k-pace)
- [PM5 How To Use (inactivity timeout context)](https://www.concept2.com/support/monitors/pm5/how-to-use)

## Endurance Sport Science

### Stephen Seiler — Polarized 80/20 Training

Sport scientist. Measured the actual training of elite endurance athletes across rowing, cycling, running, and skiing and found a consistent 80% low-intensity / 20% high-intensity distribution. Confirmed by Stöggl & Sperlich (2014) RCT.

**YAML implication:** Default intensity distribution in any plan is 80/20 polarized. The 20% high-intensity should be genuinely hard (≥92% intensity — threshold work and above). The 80% low-intensity should be genuinely easy (≤75% intensity — aerobic base). Avoid spending plan time in the 83–92% "gray zone" that feels hard but doesn't produce optimal adaptations.

**Sources:**
- [Polarized Training 201 with Dr. Stephen Seiler](https://www.youtube.com/watch?v=zKloBrc75KQ)
- [Fast Talk Labs — Polarized Training](https://www.fasttalklabs.com/pathways/polarized-training/)

### Tudor Bompa — Classical Periodization

Author of *Periodization: Theory and Methodology of Training* (1963 onward). Defined macrocycle → mesocycle (4–6 weeks) → microcycle (1 week) structure adopted by virtually every endurance sport.

**YAML implication:** Plans of 6+ weeks use 4–6 week mesocycles, each ending with a deload week (~30–50% volume drop). Plan section titles should reflect the mesocycle phase (Foundation, Build, Peak, Taper).

**Source:** [Periodization: Theory and Methodology (Bompa & Buzzichelli)](https://us.humankinetics.com/products/periodization-6th-edition)

### Vladimir Issurin — Block Periodization

Sport scientist. Block periodization concentrates 2–3 adaptations per 2–4 week block (accumulation → intensification → realization), rather than developing many abilities simultaneously.

**YAML implication:** For 4-week plans or time-constrained athletes, use a single concentrated block targeting one adaptation. For 16-week plans, chain accumulation/intensification/realization blocks.

**Sources:**
- [Block Periodization 2 — EliteFTS](https://www.elitefts.com/block-periodization-2-fundametnal-concepts-training-design.html)
- [Issurin block-periodization review (PubMed)](https://pubmed.ncbi.nlm.nih.gov/26573916/)

### Joe Friel — Ability-Based Periodization

Endurance coach, author of *The Training Bible* series. Six fitness abilities (aerobic endurance, muscular force, speed skills, muscular endurance, anaerobic endurance, sprint power) developed in sequence across base → build → specialty phases.

**YAML implication:** Within a plan, name what each phase is building (e.g., "Build Phase 2: muscular endurance"). Intensity matters more than volume for advanced athletes — taper volume but maintain intensity in peak phases.

**Sources:**
- [Joe Friel Training](https://joefrieltraining.com/biography/)
- [Fast Talk Labs — Joe Friel on coaching history](https://www.fasttalklabs.com/fast-talk/history-of-endurance-coaching-with-joe-friel/)

### Jack Daniels — VDOT Method

Running coach and exercise physiologist. Personalizes training paces from a single fitness number (VDOT, derived from a recent race). Five zones (E / M / T / I / R). 70–80% volume at Easy pace, 10–15% each at Threshold and Interval.

**YAML implication:** Anchor all intensity prescriptions to a single fitness number (FTP for rowing). All YAML `intensity` values are percentages of FTP, no absolute watts unless the workout is explicitly absolute-power (rare).

**Source:** [VDOT O2 (Jack Daniels' system)](https://vdoto2.com)

## Comparable Apps — Pattern References

### Asensei

Connected indoor-rowing coaching app. Coaches include Eric Murray, Shane Farmer, British Rowing. Plans are structured multi-week programs with PM5 integration.

**Pattern:** Plans are sold as named programs by named coaches (e.g., "Be A Dark Horse"). Programs are sequenced, not à-la-carte.

**Source:** [Asensei Rowing](https://asensei.com/pages/asensei-rowing)

### EXR

Gamified rowing app. Plans by Coach Hendrik, 6–9 weeks, FTP-anchored personalization, three intensity-level variants.

**Pattern:** FTP test gates plan entry. Plan output is personalized by FTP percentage.

**Source:** [EXR Training Mode](https://exrgame.com/support/training)

### ErgZone

Plan marketplace. Coaches sell plans directly (2K, 5K, sprints, marathon, foundation). One-time purchase, structured sequencing.

**Pattern:** Goal-named plans (2K Plan, 5K Plan) over coach-named ones. Each plan targets a specific outcome with clear week-by-week sequencing.

**Source:** [ErgZone Training Plans](https://help.erg.zone/article/43-where-can-i-find-training-plans)

### Dark Horse Rowing — Shane Farmer

Concept2 Master Instructor. Method emphasizes movement quality, mobility, mindset alongside the row.

**Pattern:** Less about periodization, more about technique-first programming. Useful for plans aimed at beginners or returning athletes.

**Source:** [Dark Horse Academy](https://darkhorseacademy.teachable.com/p/the-dark-horse-method)

## Cross-Domain (Endurance)

### TrainerRoad — Periodization Software

Cycling-focused but the periodization model (Base → Build → Specialty mesocycles, FTP-anchored, supercompensation) directly maps to rowing.

**Pattern:** 12-week macrocycles split into three 4-week mesocycles, each ending in a recovery week. Plan generator adjusts based on athlete response.

**Source:** [TrainerRoad — Training Periodization](https://www.trainerroad.com/blog/training-periodization-macro-meso-microcycles-of-training/)

### Hal Higdon — Accessible Marathon Plans

Running coach. 18–30 week marathon plans with simple weekly structure (easy / long / cross-train / rest). Wide appeal to recreational athletes.

**Pattern:** When designing for beginners or returning athletes, lean on simplicity: each session has one obvious role. Don't over-engineer.

**Source:** [Hal Higdon Marathon Plans](https://www.halhigdon.com)

### Pete Pfitzinger — Threshold-First Marathon Plans

Running coach. Five mesocycles with threshold work emphasized before VO2max. Nonlinear periodization.

**Pattern:** Some plans are threshold-anchored rather than polarized. Valid for advanced athletes targeting lactate-threshold improvement specifically.

**Source:** [Pfitzinger Marathon Plans (Running With Rock breakdown)](https://runningwithrock.com/pfitz-marathon-training-explained/)
