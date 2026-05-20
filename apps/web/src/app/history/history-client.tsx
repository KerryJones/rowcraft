'use client';

import { useMemo, useState } from 'react';
import type { SplitData, WorkoutResult } from '@/lib/types';
import { formatTimeTenths, formatTimeMs, formatPace, formatDistance } from '@/lib/utils/format';
import { timeInZone, timeInZoneBySegment } from '@/lib/utils/hr-zones';
import { HrZoneDonut } from '@/components/ui/hr-zone-donut';
import { Cloud, CloudOff, ChevronDown, ChevronRight } from 'lucide-react';

export interface HrProfile {
  maxHr: number | null;
  restingHr: number | null;
}

interface HistoryClientProps {
  results: WorkoutResult[];
  workoutTitles: Record<string, string>;
  hrProfile: HrProfile;
}

const DEFAULT_MAX_HR = 190;

export function HistoryClient({ results, workoutTitles, hrProfile }: HistoryClientProps) {
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());

  function toggleExpand(id: string) {
    setExpandedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  if (results.length === 0) {
    return (
      <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
        <h1 className="mb-8 text-3xl font-bold text-white">History</h1>
        <div className="py-16 text-center text-gray-500">
          No workout results yet. Complete a workout on the RowCraft mobile app to see your history.
        </div>
      </div>
    );
  }

  const maxHr = hrProfile.maxHr ?? DEFAULT_MAX_HR;
  const restingHr = hrProfile.restingHr;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="mb-8 text-3xl font-bold text-white">History</h1>

      <div className="space-y-3">
        {results.map((result) => {
          const isExpanded = expandedIds.has(result.id);
          const date = new Date(result.started_at);
          const workoutTitle = result.workout_id
            ? workoutTitles[result.workout_id] ?? 'Unknown Workout'
            : 'Free Row';

          return (
            <HistoryRow
              key={result.id}
              result={result}
              isExpanded={isExpanded}
              workoutTitle={workoutTitle}
              date={date}
              onToggle={() => toggleExpand(result.id)}
              maxHr={maxHr}
              restingHr={restingHr}
            />
          );
        })}
      </div>
    </div>
  );
}

interface HistoryRowProps {
  result: WorkoutResult;
  isExpanded: boolean;
  workoutTitle: string;
  date: Date;
  onToggle: () => void;
  maxHr: number;
  restingHr: number | null;
}

function HistoryRow({
  result,
  isExpanded,
  workoutTitle,
  date,
  onToggle,
  maxHr,
  restingHr,
}: HistoryRowProps) {
  // Memoize on `result.time_samples` (the stable prop reference) rather than
  // `samples` (recreated each render when `time_samples` is null).
  const summaryTiz = useMemo(
    () => timeInZone(result.time_samples ?? [], restingHr, maxHr),
    [result.time_samples, restingHr, maxHr],
  );
  const tizBySegment = useMemo(
    () => timeInZoneBySegment(result.time_samples ?? [], restingHr, maxHr),
    [result.time_samples, restingHr, maxHr],
  );

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 overflow-hidden">
      <button
        type="button"
        onClick={onToggle}
        className="flex w-full cursor-pointer items-center justify-between p-4 text-left"
      >
        <div className="flex-1">
          <div className="flex items-center gap-3">
            <span className="text-sm font-semibold text-white">{workoutTitle}</span>
            {result.synced_to_c2 ? (
              <span title="Synced to C2 Logbook"><Cloud className="h-4 w-4 text-emerald-400" /></span>
            ) : (
              <span title="Not synced"><CloudOff className="h-4 w-4 text-gray-500" /></span>
            )}
          </div>
          <p className="mt-0.5 text-xs text-gray-500">
            {date.toLocaleDateString('en-US', {
              weekday: 'short',
              month: 'short',
              day: 'numeric',
              year: 'numeric',
            })}
          </p>

          {/* Stats row */}
          <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-400">
            <span>Time: {formatTimeTenths(result.total_time)}</span>
            <span>Dist: {formatDistance(result.total_distance)}</span>
            <span>Split: {formatPace(result.avg_split)}/500m</span>
            <span>SPM: {result.avg_stroke_rate}</span>
            {result.avg_heart_rate && (
              <span>HR: {result.avg_heart_rate}bpm</span>
            )}
            {result.calories && (
              <span>{result.calories}cal</span>
            )}
          </div>
        </div>

        <div className="ml-3 flex shrink-0 items-center gap-3">
          <HrZoneDonut timeInZone={summaryTiz} size={36} strokeWidth={5} />
          {isExpanded ? (
            <ChevronDown className="h-4 w-4 text-gray-400" />
          ) : (
            <ChevronRight className="h-4 w-4 text-gray-400" />
          )}
        </div>
      </button>

      {/* Expanded: per-segment splits */}
      {isExpanded && result.splits && result.splits.length > 0 && (
        <SplitDetails splits={result.splits} tizBySegment={tizBySegment} />
      )}
    </div>
  );
}

interface SplitDetailsProps {
  splits: SplitData[];
  tizBySegment: Record<number, Record<number, number>>;
}

const SPLIT_COL = {
  pace: 'w-[5.5rem] text-right',
  dist: 'w-[3.5rem] text-right',
  time: 'w-[3.5rem] text-right',
  spm: 'w-[3rem] text-right',
  zone: 'w-7 inline-flex justify-center',
  bpm: 'w-[3rem] text-right',
} as const;

function SplitDetails({ splits, tizBySegment }: SplitDetailsProps) {
  const isAutoSplit = splits.length > 1 &&
    splits.every(s => s.segment_index === splits[0].segment_index);

  // Precompute cumulative distances for auto-split labels
  const cumDistances = isAutoSplit
    ? splits.reduce<number[]>((acc, s) => {
        acc.push((acc[acc.length - 1] ?? 0) + s.distance);
        return acc;
      }, [])
    : [];

  return (
    <div className="border-t border-gray-800 p-4">
      <h4 className="mb-2 text-xs font-medium text-gray-500">
        {isAutoSplit ? 'Splits' : 'Segment Splits'}
      </h4>
      <div className="space-y-1.5">
        <div className="flex items-center justify-between px-3 py-1 text-[10px] font-semibold uppercase tracking-wider text-gray-500">
          <span className="flex items-center gap-2">
            {isAutoSplit ? 'Split' : 'Segment'}
          </span>
          <div className="flex flex-wrap gap-x-4 gap-y-1">
            <span className={SPLIT_COL.pace}>Pace</span>
            <span className={SPLIT_COL.dist}>Dist</span>
            <span className={SPLIT_COL.time}>Time</span>
            <span className={SPLIT_COL.spm}>SPM</span>
            <span className={SPLIT_COL.zone}>Zone</span>
            <span className={SPLIT_COL.bpm}>BPM</span>
          </div>
        </div>
        {splits.map((split, i) => {
          const isRest = split.is_rest === true;
          const label = isAutoSplit
            ? formatDistance(Math.round(cumDistances[i]))
            : isRest
              ? 'Rest'
              : `Segment ${split.segment_index + 1}`;
          const tiz = tizBySegment[split.segment_index] ?? {};

          return (
            <div
              key={i}
              className={`flex items-center justify-between rounded-lg bg-gray-800/50 px-3 py-2 text-xs ${
                isRest ? 'text-gray-500' : 'text-gray-300'
              }`}
            >
              <span className={isRest ? 'font-medium' : 'text-gray-400'}>
                {label}
              </span>
              <div className="flex flex-wrap items-center gap-x-4 gap-y-1 font-mono">
                <span className={SPLIT_COL.pace}>{formatPace(split.avg_pace)}/500m</span>
                <span className={SPLIT_COL.dist}>{formatDistance(split.distance)}</span>
                <span className={SPLIT_COL.time}>{formatTimeMs(split.time_ms)}</span>
                <span className={SPLIT_COL.spm}>{split.avg_stroke_rate}spm</span>
                <span className={SPLIT_COL.zone}>
                  <HrZoneDonut timeInZone={tiz} size={14} strokeWidth={2} />
                </span>
                <span className={SPLIT_COL.bpm}>
                  {split.avg_heart_rate ? `${split.avg_heart_rate}bpm` : '—'}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
