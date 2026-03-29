'use client';

import { useState } from 'react';
import Link from 'next/link';
import type { PlanWeek } from '@/lib/types';
import { ChevronDown, ChevronRight } from 'lucide-react';

interface PlanWeeksAccordionProps {
  weeks: PlanWeek[];
  workoutTitles: Record<string, string>;
}

export function PlanWeeksAccordion({ weeks, workoutTitles }: PlanWeeksAccordionProps) {
  const [openWeeks, setOpenWeeks] = useState<Set<number>>(new Set([0]));

  function toggleWeek(index: number) {
    setOpenWeeks((prev) => {
      const next = new Set(prev);
      if (next.has(index)) {
        next.delete(index);
      } else {
        next.add(index);
      }
      return next;
    });
  }

  return (
    <div className="space-y-3">
      {weeks.map((week, i) => {
        const isOpen = openWeeks.has(i);

        return (
          <div
            key={i}
            className="rounded-xl border border-gray-800 bg-gray-900 overflow-hidden"
          >
            <button
              type="button"
              onClick={() => toggleWeek(i)}
              className="flex w-full cursor-pointer items-center justify-between p-4 text-left"
            >
              <div>
                <span className="text-sm font-semibold text-white">
                  Week {week.week_number}
                </span>
                {week.title && (
                  <span className="ml-2 text-sm text-gray-400">{week.title}</span>
                )}
              </div>
              <div className="flex items-center gap-2">
                <span className="text-xs text-gray-500">
                  {week.sessions.length} session{week.sessions.length !== 1 ? 's' : ''}
                </span>
                {isOpen ? (
                  <ChevronDown className="h-4 w-4 text-gray-400" />
                ) : (
                  <ChevronRight className="h-4 w-4 text-gray-400" />
                )}
              </div>
            </button>

            {isOpen && (
              <div className="border-t border-gray-800 p-4">
                <div className="space-y-2">
                  {week.sessions.map((session, j) => (
                    <div
                      key={j}
                      className="flex items-center justify-between rounded-lg bg-gray-800/50 px-3 py-2"
                    >
                      <div className="flex items-center gap-3">
                        <span className="text-xs font-medium text-gray-500">
                          {session.day_label}
                        </span>
                        <Link
                          href={`/workouts/${session.workout_id}`}
                          className="text-sm text-blue-400 hover:text-blue-300"
                        >
                          {workoutTitles[session.workout_id] ?? 'Unknown Workout'}
                        </Link>
                      </div>
                      {session.notes && (
                        <span className="text-xs text-gray-500">{session.notes}</span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
