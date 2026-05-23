/**
 * Concept2 Logbook API payload building utilities.
 *
 * Pure functions for mapping RowCraft data models to C2 API format.
 */

import type { WorkoutSegment as FullWorkoutSegment } from '@/lib/types';

// --- Types ---

/** Subset of WorkoutSegment fields needed for C2 payload building. */
export type C2Segment = Pick<FullWorkoutSegment, 'duration_type' | 'duration_value' | 'is_rest'>;

export type RowCraftWorkoutType = 'single_distance' | 'single_time' | 'intervals' | 'variable_intervals';

export interface SplitJson {
  segment_index: number;
  distance: number;
  time_ms: number;
  avg_pace: number;
  avg_stroke_rate: number;
  avg_watts: number;
  avg_heart_rate?: number;
  min_heart_rate?: number;
  max_heart_rate?: number;
  ending_heart_rate?: number;
  calories: number;
}

export interface TimeSampleJson {
  t: number;   // ms
  d: number;   // meters
  p: number;   // pace tenths/500m
  spm: number;
  hr?: number;
  si: number;  // segment index
}

// --- Functions ---

export function mapC2WorkoutType(
  workoutType: RowCraftWorkoutType | null,
  segments: C2Segment[],
): string {
  if (workoutType == null) return 'JustRow';

  switch (workoutType) {
    case 'single_distance':
      return 'FixedDistanceSplits';
    case 'single_time':
      return 'FixedTimeSplits';
    case 'intervals': {
      const workSeg = segments.find(s => !s.is_rest);
      if (!workSeg) return 'FixedDistanceInterval';
      switch (workSeg.duration_type) {
        case 'distance': return 'FixedDistanceInterval';
        case 'time': return 'FixedTimeInterval';
        case 'calories': return 'FixedCalorieInterval';
      }
      break;
    }
    case 'variable_intervals':
      return 'VariableInterval';
    default:
      return 'JustRow';
  }
}

export function buildHeartRateObject(
  avg?: number | null,
  min?: number | null,
  max?: number | null,
  ending?: number | null,
): Record<string, number> | undefined {
  if (avg == null && min == null && max == null && ending == null) return undefined;
  const hr: Record<string, number> = {};
  if (avg != null) hr.average = avg;
  if (min != null) hr.min = min;
  if (max != null) hr.max = max;
  if (ending != null) hr.ending = ending;
  return hr;
}

function buildSplitHeartRate(split: SplitJson): Record<string, number> | undefined {
  return buildHeartRateObject(
    split.avg_heart_rate,
    split.min_heart_rate,
    split.max_heart_rate,
    split.ending_heart_rate,
  );
}

export function buildSplits(splits: SplitJson[]): Record<string, unknown>[] {
  return splits.map(s => {
    const timeInTenths = Math.round(s.time_ms / 100);
    const c2Split: Record<string, unknown> = {
      distance: Math.round(s.distance),
      time: timeInTenths,
    };
    if (s.avg_stroke_rate > 0) c2Split.stroke_rate = s.avg_stroke_rate;
    if (s.calories > 0) c2Split.calories_total = s.calories;
    if (s.avg_watts > 0) {
      c2Split.wattminutes_total = Math.round(s.avg_watts * (s.time_ms / 60000));
    }
    const hr = buildSplitHeartRate(s);
    if (hr) c2Split.heart_rate = hr;
    return c2Split;
  });
}

export interface IntervalsResult {
  intervals: Record<string, unknown>[];
  totalRestTime: number;
  totalRestDistance: number;
}

export function buildIntervals(
  splits: SplitJson[],
  segments: C2Segment[],
): IntervalsResult {
  const intervals: Record<string, unknown>[] = [];
  let totalRestTime = 0;
  let totalRestDistance = 0;

  for (let i = 0; i < splits.length; i++) {
    const split = splits[i];
    const seg = segments[split.segment_index];
    if (!seg) continue;
    if (seg.is_rest) {
      totalRestTime += Math.round(split.time_ms / 100);
      totalRestDistance += Math.round(split.distance);
      continue;
    }

    const timeInTenths = Math.round(split.time_ms / 100);
    const interval: Record<string, unknown> = {
      type: seg.duration_type === 'calories' ? 'calorie' : seg.duration_type,
      distance: Math.round(split.distance),
      time: timeInTenths,
    };

    if (split.avg_stroke_rate > 0) interval.stroke_rate = split.avg_stroke_rate;
    if (split.calories > 0) interval.calories_total = split.calories;
    if (split.avg_watts > 0) {
      interval.wattminutes_total = Math.round(split.avg_watts * (split.time_ms / 60000));
    }

    const hr = buildSplitHeartRate(split);
    if (hr) interval.heart_rate = hr;

    const restSegIndex = split.segment_index + 1;
    const restSeg = segments[restSegIndex];
    if (restSeg?.is_rest) {
      const restSplit = splits.find(s => s.segment_index === restSegIndex);
      if (restSplit) {
        interval.rest_time = Math.round(restSplit.time_ms / 100);
        if (restSplit.distance > 0) {
          interval.rest_distance = Math.round(restSplit.distance);
        }
      } else {
        if (restSeg.duration_type === 'time') {
          interval.rest_time = Math.round(restSeg.duration_value * 10);
        }
      }
    } else {
      interval.rest_time = 0;
    }

    intervals.push(interval);
  }

  return { intervals, totalRestTime, totalRestDistance };
}

/** Map a single time sample to C2 stroke_data format, with optional rebase offsets. */
function mapSampleToStroke(
  s: TimeSampleJson,
  baseT = 0,
  baseD = 0,
): Record<string, unknown> {
  const stroke: Record<string, unknown> = {
    t: Math.round((s.t - baseT) / 100),   // ms -> tenths of seconds
    d: Math.round((s.d - baseD) * 10),     // meters -> decimeters
    p: s.p,                                // already tenths/500m
    spm: s.spm,
  };
  if (s.hr != null) stroke.hr = s.hr;
  return stroke;
}

export function buildStrokeData(timeSamples: TimeSampleJson[]): Record<string, unknown>[] {
  return timeSamples.map(s => mapSampleToStroke(s));
}

/**
 * Build stroke_data for interval workouts. C2 expects timestamps and distance
 * to reset to 0 at each interval boundary — it infers interval breaks from
 * these resets. Rest segment samples are excluded.
 */
export function buildIntervalStrokeData(
  timeSamples: TimeSampleJson[],
  segments: C2Segment[],
): Record<string, unknown>[] {
  // Group samples by segment index
  const bySegment = new Map<number, TimeSampleJson[]>();
  for (const s of timeSamples) {
    const group = bySegment.get(s.si) ?? [];
    group.push(s);
    bySegment.set(s.si, group);
  }

  const result: Record<string, unknown>[] = [];

  // Process each segment in order, skip rest segments
  const sortedKeys = [...bySegment.keys()].sort((a, b) => a - b);
  for (const si of sortedKeys) {
    const seg = segments[si];
    if (!seg || seg.is_rest) continue;

    const samples = bySegment.get(si)!;
    if (samples.length === 0) continue;

    // Sort by timestamp in case DB returns out of order
    samples.sort((a, b) => a.t - b.t);

    // Rebase so each interval starts at t=0, d=0
    const baseT = samples[0].t;
    const baseD = samples[0].d;
    for (const s of samples) {
      result.push(mapSampleToStroke(s, baseT, baseD));
    }
  }

  return result;
}
