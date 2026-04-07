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
	/** Strokes per minute target (10–50). */
	target_stroke_rate: number | null;
	/** HR zone (1–5) derived from target_intensity at build/save time. Read-only. */
	target_hr_zone: number | null;
	messages: SegmentMessage[] | null;
}

/** True when a segment has no targets — pure rest/recovery time. */
export function isRestSegment(seg: WorkoutSegment): boolean {
	return seg.target_intensity == null && seg.target_stroke_rate == null;
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
	created_at: string;
	updated_at: string;
}

export type HrZoneName = 'recovery' | 'aerobic' | 'tempo' | 'threshold' | 'max';

export interface HrZone {
	name: HrZoneName;
	label: string;
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
