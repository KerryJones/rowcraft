/**
 * TCX (Training Center XML) builder for Strava uploads.
 *
 * Converts RowCraft workout result data into a valid TCX document
 * that Strava can parse for full telemetry (HR, stroke rate, distance).
 */

import type { WorkoutSegment as FullWorkoutSegment } from '@/lib/types';
import { formatPace, formatDuration, formatDistance } from '@/lib/utils/format';

export type TcxSegment = Pick<FullWorkoutSegment, 'duration_type' | 'duration_value' | 'is_rest'>;

export interface TcxSplitJson {
  segment_index: number;
  distance: number;
  time_ms: number;
  avg_pace: number;
  avg_stroke_rate: number;
  avg_watts: number;
  avg_heart_rate?: number;
  min_heart_rate?: number;
  max_heart_rate?: number;
  calories: number;
}

export interface TcxTimeSampleJson {
  t: number;   // ms from workout start
  d: number;   // cumulative meters
  p: number;   // pace tenths/500m
  spm: number; // strokes per minute
  hr?: number; // heart rate bpm
  si: number;  // segment index
}

interface TcxWorkoutData {
  started_at: string;
  finished_at: string;
  total_distance: number;       // meters
  total_time: number;           // tenths of seconds
  avg_heart_rate?: number | null;
  max_heart_rate?: number | null;
  avg_stroke_rate?: number | null;
  calories?: number | null;
  splits: TcxSplitJson[];
  time_samples: TcxTimeSampleJson[];
  segments: TcxSegment[];
  workout_type: string | null;
  workout_title?: string | null;
}

function toIso(date: Date): string {
  return date.toISOString();
}

function msToIso(startDate: Date, ms: number): string {
  return new Date(startDate.getTime() + ms).toISOString();
}

/**
 * Build a trackpoint XML element from a time sample.
 * Cadence in TCX is limited to 0-254 (xs:unsignedByte).
 */
function buildTrackpoint(
  startDate: Date,
  sample: TcxTimeSampleJson,
): string {
  const lines: string[] = [];
  lines.push('            <Trackpoint>');
  lines.push(`              <Time>${msToIso(startDate, sample.t)}</Time>`);
  lines.push(`              <DistanceMeters>${sample.d.toFixed(1)}</DistanceMeters>`);
  if (sample.hr != null && sample.hr > 0) {
    lines.push('              <HeartRateBpm>');
    lines.push(`                <Value>${sample.hr}</Value>`);
    lines.push('              </HeartRateBpm>');
  }
  if (sample.spm > 0) {
    lines.push(`              <Cadence>${Math.min(sample.spm, 254)}</Cadence>`);
  }
  lines.push('            </Trackpoint>');
  return lines.join('\n');
}

/**
 * Build a single Lap element from split data and associated time samples.
 */
function buildLap(
  startDate: Date,
  split: TcxSplitJson,
  samples: TcxTimeSampleJson[],
  lapStartTime: Date,
): string {
  const lines: string[] = [];
  const totalSeconds = split.time_ms / 1000;

  lines.push(`        <Lap StartTime="${toIso(lapStartTime)}">`);
  lines.push(`          <TotalTimeSeconds>${totalSeconds.toFixed(1)}</TotalTimeSeconds>`);
  lines.push(`          <DistanceMeters>${split.distance.toFixed(1)}</DistanceMeters>`);
  if (split.calories > 0) {
    lines.push(`          <Calories>${split.calories}</Calories>`);
  }
  if (split.avg_heart_rate != null && split.avg_heart_rate > 0) {
    lines.push('          <AverageHeartRateBpm>');
    lines.push(`            <Value>${split.avg_heart_rate}</Value>`);
    lines.push('          </AverageHeartRateBpm>');
  }
  if (split.max_heart_rate != null && split.max_heart_rate > 0) {
    lines.push('          <MaximumHeartRateBpm>');
    lines.push(`            <Value>${split.max_heart_rate}</Value>`);
    lines.push('          </MaximumHeartRateBpm>');
  }
  if (split.avg_stroke_rate > 0) {
    lines.push(`          <Cadence>${Math.min(split.avg_stroke_rate, 254)}</Cadence>`);
  }
  lines.push('          <Intensity>Active</Intensity>');
  lines.push('          <TriggerMethod>Manual</TriggerMethod>');

  if (samples.length > 0) {
    lines.push('          <Track>');
    for (const sample of samples) {
      lines.push(buildTrackpoint(startDate, sample));
    }
    lines.push('          </Track>');
  }

  lines.push('        </Lap>');
  return lines.join('\n');
}

/**
 * Build a complete TCX XML document from a workout result.
 *
 * For interval workouts with segments, creates one Lap per work segment.
 * For single-piece workouts, creates one Lap for the entire activity.
 * Rest segments are excluded from the TCX (Strava doesn't need them).
 */
export function buildTcx(data: TcxWorkoutData): string {
  const startDate = new Date(data.started_at);
  const isInterval = (data.workout_type === 'intervals' || data.workout_type === 'variable_intervals')
    && data.segments.length > 0;

  // Group time samples by segment index, sorted by timestamp
  const samplesBySegment = new Map<number, TcxTimeSampleJson[]>();
  for (const s of data.time_samples) {
    const group = samplesBySegment.get(s.si) ?? [];
    group.push(s);
    samplesBySegment.set(s.si, group);
  }
  for (const samples of samplesBySegment.values()) {
    samples.sort((a, b) => a.t - b.t);
  }

  const laps: string[] = [];

  if (isInterval && data.splits.length > 0) {
    let cumulativeMs = 0;
    for (const split of data.splits) {
      const seg = data.segments[split.segment_index];
      if (seg?.is_rest) {
        cumulativeMs += split.time_ms;
        continue;
      }

      const lapStartTime = new Date(startDate.getTime() + cumulativeMs);
      const samples = samplesBySegment.get(split.segment_index) ?? [];
      laps.push(buildLap(startDate, split, samples, lapStartTime));
      cumulativeMs += split.time_ms;
    }
  } else if (data.splits.length > 0) {
    let cumulativeMs = 0;
    for (const split of data.splits) {
      const lapStartTime = new Date(startDate.getTime() + cumulativeMs);
      const samples = samplesBySegment.get(split.segment_index) ?? [];
      laps.push(buildLap(startDate, split, samples, lapStartTime));
      cumulativeMs += split.time_ms;
    }
  }

  // Fallback: if no splits, create a single lap from summary data
  if (laps.length === 0) {
    const totalSeconds = data.total_time / 10;
    const allSamples = [...data.time_samples].sort((a, b) => a.t - b.t);

    const fallbackSplit: TcxSplitJson = {
      segment_index: 0,
      distance: data.total_distance,
      time_ms: totalSeconds * 1000,
      avg_pace: 0,
      avg_stroke_rate: data.avg_stroke_rate ?? 0,
      avg_watts: 0,
      avg_heart_rate: data.avg_heart_rate ?? undefined,
      max_heart_rate: data.max_heart_rate ?? undefined,
      calories: data.calories ?? 0,
    };

    laps.push(buildLap(startDate, fallbackSplit, allSamples, startDate));
  }

  const lines: string[] = [];
  lines.push('<?xml version="1.0" encoding="UTF-8"?>');
  lines.push('<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">');
  lines.push('  <Activities>');
  lines.push('    <Activity Sport="Other">');
  lines.push(`      <Id>${toIso(startDate)}</Id>`);
  lines.push(laps.join('\n'));
  lines.push('    </Activity>');
  lines.push('  </Activities>');
  lines.push('</TrainingCenterDatabase>');

  return lines.join('\n');
}

/**
 * Build a human-readable description for the Strava activity.
 */
export function buildStravaDescription(data: {
  total_distance: number;
  total_time: number;
  avg_stroke_rate?: number | null;
  avg_split?: number | null;
}): string {
  const parts: string[] = [];

  if (data.total_distance > 0) {
    parts.push(formatDistance(data.total_distance));
  }

  if (data.total_time > 0) {
    parts.push(formatDuration(Math.round(data.total_time / 10)));
  }

  if (data.avg_split != null && data.avg_split > 0) {
    parts.push(`${formatPace(data.avg_split)}/500m`);
  }

  // Stroke rate
  if (data.avg_stroke_rate != null && data.avg_stroke_rate > 0) {
    parts.push(`${data.avg_stroke_rate} spm`);
  }

  if (parts.length === 0) return 'RowCraft Rowing';
  return parts.join(' | ');
}
