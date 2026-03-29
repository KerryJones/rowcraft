'use client';

import { useState } from 'react';
import type { WorkoutResult } from '@/lib/types';
import { formatTimeTenths, formatPace, formatDistance } from '@/lib/utils/format';
import { Cloud, CloudOff, ChevronDown, ChevronRight } from 'lucide-react';

interface HistoryClientProps {
  results: WorkoutResult[];
  workoutTitles: Record<string, string>;
}

export function HistoryClient({ results, workoutTitles }: HistoryClientProps) {
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
            <div
              key={result.id}
              className="rounded-xl border border-gray-800 bg-gray-900 overflow-hidden"
            >
              <button
                type="button"
                onClick={() => toggleExpand(result.id)}
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

                {isExpanded ? (
                  <ChevronDown className="h-4 w-4 shrink-0 text-gray-400" />
                ) : (
                  <ChevronRight className="h-4 w-4 shrink-0 text-gray-400" />
                )}
              </button>

              {/* Expanded: per-segment splits */}
              {isExpanded && result.splits && result.splits.length > 0 && (
                <div className="border-t border-gray-800 p-4">
                  <h4 className="mb-2 text-xs font-medium text-gray-500">Segment Splits</h4>
                  <div className="space-y-1.5">
                    {result.splits.map((split, i) => (
                      <div
                        key={i}
                        className="flex items-center justify-between rounded-lg bg-gray-800/50 px-3 py-2 text-xs"
                      >
                        <span className="text-gray-400">Segment {split.segment_index + 1}</span>
                        <div className="flex gap-4 text-gray-300">
                          <span>{formatPace(split.avg_split)}/500m</span>
                          <span>{formatDistance(split.distance)}</span>
                          <span>{formatTimeTenths(split.time)}</span>
                          <span>{split.avg_stroke_rate}spm</span>
                          {split.avg_heart_rate && (
                            <span>{split.avg_heart_rate}bpm</span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
