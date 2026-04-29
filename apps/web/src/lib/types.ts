export type DurationType = 'time' | 'distance' | 'calories';
export type WorkoutType = 'single_distance' | 'single_time' | 'intervals' | 'variable_intervals';

export interface SegmentMessage {
	trigger_type: 'time' | 'distance' | 'start' | 'end';
	trigger_value: number; // seconds or meters (0 for start/end)
	text: string;
}

export interface WorkoutSegment {
	duration_type: DurationType;
	duration_value: number; // seconds, meters, or calories depending on duration_type
	/** FTP percentage target (0–200). Higher % = more watts = faster pace. */
	target_intensity: number | null;
	/** Absolute watt target. Takes precedence over target_intensity. */
	target_watts: number | null;
	/** Strokes per minute target (10–50). */
	target_stroke_rate: number | null;
	/** HR zone (1–5) derived from target_intensity at build/save time. Read-only. */
	target_hr_zone: number | null;
	/** True when this segment is an explicit rest interval. Free-row segments with no
	 *  targets are NOT rest — only segments originating from an interval rest: block. */
	is_rest?: boolean;
	messages: SegmentMessage[] | null;
}

/** True when a segment is an explicit rest interval. */
export function isRestSegment(seg: WorkoutSegment): boolean {
	return seg.is_rest === true;
}

/** Default FTP for users who haven't taken an FTP test. 150W ≈ 2:14/500m. */
export const DEFAULT_FTP_WATTS = 150;

/**
 * Normalize all segments in a workout.
 * Call this when loading workouts from the database.
 */
export function normalizeWorkoutSegments(segments: WorkoutSegment[]): WorkoutSegment[] {
	return segments.map((seg) => ({
		...seg,
		target_watts: seg.target_watts ?? null,
		messages: seg.messages ?? null,
	}));
}

export interface Workout {
	id: string;
	author_id: string | null;
	title: string;
	description: string;
	workout_type: WorkoutType;
	segments: WorkoutSegment[];
	tags: string[];
	is_public: boolean;
	fork_count: number;
	forked_from: string | null;
	created_at: string;
	updated_at: string;
}

export interface SplitData {
	segment_index: number;
	distance: number;
	time: number; // tenths of seconds
	avg_split: number; // tenths of a second per 500m
	avg_stroke_rate: number;
	avg_heart_rate: number | null;
	avg_watts: number;
}

export interface WorkoutResult {
	id: string;
	user_id: string;
	workout_id: string | null;
	started_at: string;
	finished_at: string | null;
	total_distance: number; // meters
	total_time: number; // tenths of seconds
	avg_split: number; // tenths of a second per 500m
	avg_stroke_rate: number;
	avg_heart_rate: number | null;
	avg_watts: number;
	calories: number | null;
	splits: SplitData[] | null;
	synced_to_c2: boolean;
	created_at: string;
}

export interface Profile {
	id: string;
	display_name: string | null;
	c2_user_id: string | null;
	current_ftp_watts: number | null;
	max_heart_rate: number | null;
	weight_kg: number | null;
	resting_heart_rate: number | null;
	zone_system: ZoneSystem;
	onboarding_completed: boolean;
	created_at: string;
	updated_at: string;
}

export type ZoneSystem = 'standard' | 'rowing';

export type HrZoneName = 'aerobic' | 'tempo' | 'threshold' | 'vo2max' | 'max';

export interface HrZone {
	name: HrZoneName;
	/** Label for standard mode. */
	label: string;
	/** Short label for standard mode (Z1-Z5). */
	shortLabel: string;
	/** Label for rowing mode. */
	rowingLabel: string;
	/** Short label for rowing mode (UT2, UT1, AT, TR, AN). */
	rowingShortLabel: string;
	minPct: number;
	maxPct: number;
}

export interface PlanSession {
	day_label: string;
	workout_id: string;
	notes: string | null;
}

export interface PlanWeek {
	week_number: number;
	title: string;
	sessions: PlanSession[];
}

export type Difficulty = 'beginner' | 'intermediate' | 'advanced';

export interface TrainingPlan {
	id: string;
	slug: string;
	author_id: string | null;
	title: string;
	description: string;
	difficulty: Difficulty;
	duration_weeks: number;
	sessions_per_week: number;
	tags: string[];
	weeks: PlanWeek[];
	is_active: boolean;
	created_at: string;
	updated_at: string;
}

export type PrType =
	| 'fastest_500m'
	| 'fastest_2k'
	| 'fastest_5k'
	| 'fastest_6k'
	| 'fastest_10k'
	| 'fastest_half_marathon'
	| 'fastest_marathon'
	| 'highest_ftp'
	| 'longest_distance';

export interface PersonalRecord {
	id: string;
	user_id: string;
	pr_type: PrType;
	value: number;
	result_id: string | null;
	achieved_at: string;
	previous_value: number | null;
	created_at: string;
	updated_at: string;
}

export type AchievementType =
	| 'total_distance'
	| 'workout_count'
	| 'plan_completed'
	| 'streak_days';

export interface Achievement {
	id: string;
	user_id: string;
	achievement_type: AchievementType;
	threshold: number;
	achieved_at: string;
	result_id: string | null;
	created_at: string;
}
