export type SegmentType = 'work' | 'rest' | 'warmup' | 'cooldown';
export type DurationType = 'time' | 'distance' | 'calories';
export type WorkoutType = 'single_distance' | 'single_time' | 'intervals' | 'variable_intervals';

export interface SplitTarget {
	min: number; // tenths of a second per 500m
	max: number;
}

export interface StrokeRateTarget {
	min: number;
	max: number;
}

export interface WorkoutSegment {
	type: SegmentType;
	duration_type: DurationType;
	duration_value: number; // seconds, meters, or calories depending on duration_type
	target_split: SplitTarget | null;
	target_stroke_rate: StrokeRateTarget | null;
	target_hr_zone: number | null;
	repeat: number;
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
	created_at: string;
	updated_at: string;
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
