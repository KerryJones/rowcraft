# Database Schema

All migrations in `supabase/migrations/`. Run `supabase db reset` to apply all.

## Tables

### profiles
Extends Supabase `auth.users`. Auto-created on signup via trigger.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | References auth.users |
| display_name | text | |
| c2_user_id | text | Concept2 account ID |
| c2_access_token, c2_refresh_token | text | C2 OAuth tokens |
| current_ftp_watts | int | Power threshold |
| max_heart_rate | int | For HR zone calculations |
| weight_kg | float | Used for C2 Logbook calorie sync |

### workouts
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| author_id | UUID FK | → profiles |
| title, description | text | |
| workout_type | text | single_distance, single_time, intervals, variable_intervals |
| segments | JSONB | Array of WorkoutSegment objects |
| tags | text[] | Max 10, GIN indexed |
| is_public | bool | |
| fork_count | int | |
| forked_from | UUID FK | Self-referencing |

### workout_results
| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK | → profiles |
| workout_id | UUID FK | → workouts (nullable for free rows) |
| total_distance | int | meters |
| total_time | int | **tenths of seconds** |
| avg_split | int | **tenths/500m** |
| avg_stroke_rate, avg_heart_rate, avg_watts, calories | int | |
| splits | JSONB | Per-segment data array |
| synced_to_c2 | bool | |

### ftp_history
Tracks FTP tests over time. Links to workout_results via source_result_id.
Test types: `ramp`, `20min`, `manual`.

### training_plans
| Column | Type | Notes |
|--------|------|-------|
| author_id | UUID FK | → profiles (nullable, added in migration 009) |
| slug | text unique | URL-friendly identifier |
| difficulty | text | beginner, intermediate, advanced |
| weeks | JSONB | Array of {week_number, title, sessions[]} |

### user_plan_progress
Tracks per-user plan completion. Unique on (user_id, plan_id).
`completed_sessions` JSONB: array of {week, session, result_id, completed_at}.

### personal_records
One row per (user, pr_type), upserted on improvement.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK | → profiles |
| pr_type | text | e.g. 'fastest_2k', 'longest_distance' |
| value | int | tenths/500m for pace, meters for distance, watts for FTP |
| result_id | UUID FK | → workout_results (nullable) |
| achieved_at | timestamptz | |
| previous_value | int | For "was X, now Y" display |

### achievements
One row per (user, achievement_type, threshold), inserted once.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK | → profiles |
| achievement_type | text | e.g. 'total_distance', 'streak_days' |
| threshold | int | e.g. 1000000 for 1M meters |
| achieved_at | timestamptz | |
| result_id | UUID FK | → workout_results (nullable) |

## RLS Policies

- **Profiles**: own row only
- **Workouts**: own + public (read), own only (write/delete)
- **Results**: own only
- **FTP History**: own only
- **Plans**: all authenticated users (read), authors can create/update/delete own plans
- **Plan Progress**: own only
- **Personal Records**: own only (select/insert/update)
- **Achievements**: own only (select/insert)

## Migrations

1. `001_users.sql` — profiles table + new user trigger
2. `002_workouts.sql` — workouts table + indexes
3. `003_results.sql` — workout_results table
4. `004_rls.sql` — RLS policies
5. `005_updated_at_trigger.sql` — updated_at trigger
6. `006_ftp.sql` — FTP watts + ftp_history table
7. `007_training_plans.sql` — training_plans + user_plan_progress
8. `008_max_heart_rate.sql` — max_heart_rate column
9. `009_plan_author.sql` — author_id on training_plans + RLS for plan ownership
10. `010_sync_all_workout_segments.sql` — sync all workout segments
11. `011_add_weight_kg.sql` — weight_kg column on profiles
12. `012_delete_account.sql` — `delete_user_account()` RPC for self-serve account deletion (cascades through all user data)
13. `013_remove_segment_type.sql` — remove segment_type column
14. `014_admin_stats.sql` — admin statistics RPC
15. `015_c2_detail_fields.sql` — C2 detail fields on workout_results
16. `016_personal_records_achievements.sql` — personal_records + achievements tables with RLS
