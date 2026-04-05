-- RowCraft Seed Data
-- Run with: psql -f seed.sql (or execute sub-files individually)
--
-- FTP Power Zones Reference (% of FTP watts):
--   Z1 Recovery:   45-60%  | 16-20 spm
--   Z2 Aerobic:    60-75%  | 18-24 spm
--   Z3 Tempo:      75-85%  | 22-28 spm
--   Z4 Threshold:  85-100% | 26-32 spm
--   Z5 VO2max:    100-130% | 28-36 spm
--
-- target_intensity: {"min": lower_ftp_pct, "max": upper_ftp_pct}
-- App resolves to pace: ftpWatts * pct / 100 → watts → C2 pace formula

\ir seeds/00_functions.sql
\ir seeds/01_classics.sql
\ir seeds/02_pete_plan.sql
\ir seeds/03_wolverine.sql
\ir seeds/04_british_rowing.sql
\ir seeds/05_ftp_builder.sql
\ir seeds/06_return_to_rowing.sql
\ir seeds/07_2k_race_prep.sql
\ir seeds/10_zone1_recovery.sql
\ir seeds/11_zone2_aerobic.sql
\ir seeds/12_zone3_tempo.sql
\ir seeds/13_zone4_threshold.sql
\ir seeds/14_zone5_vo2max.sql
\ir seeds/15_wods.sql
\ir seeds/90_training_plans.sql
