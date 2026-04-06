'use client';

import { Clock, Activity, Zap, Flame, Heart, Wind, BookOpen } from 'lucide-react';
import type { ReactNode } from 'react';

// ── Duration categories ─────────────────────────────────────────

export type DurationBucket = 'under30' | '30to60' | 'over60';

interface DurationCategory {
  key: DurationBucket;
  label: string;
  subtitle: string;
  icon: ReactNode;
  color: string;
  activeBg: string;
  activeBorder: string;
}

const DURATION_CATEGORIES: DurationCategory[] = [
  {
    key: 'under30',
    label: 'Under 30 min',
    subtitle: 'Quick hits',
    icon: <Clock className="h-4 w-4" />,
    color: 'text-blue-400',
    activeBg: 'bg-blue-500/10',
    activeBorder: 'border-blue-500',
  },
  {
    key: '30to60',
    label: '30–60 min',
    subtitle: 'Sweet spot',
    icon: <Clock className="h-4 w-4" />,
    color: 'text-emerald-400',
    activeBg: 'bg-emerald-500/10',
    activeBorder: 'border-emerald-500',
  },
  {
    key: 'over60',
    label: '60+ min',
    subtitle: 'Long haul',
    icon: <Clock className="h-4 w-4" />,
    color: 'text-amber-400',
    activeBg: 'bg-amber-500/10',
    activeBorder: 'border-amber-500',
  },
];

// ── Zone categories ─────────────────────────────────────────────

export interface ZoneCategory {
  key: string;
  label: string;
  zone: string;
  tag: string;
  icon: ReactNode;
  color: string;
  activeBg: string;
  activeBorder: string;
}

const ZONE_CATEGORIES: ZoneCategory[] = [
  {
    key: 'recovery',
    label: 'Recovery',
    zone: 'Z1',
    tag: 'recovery',
    icon: <Heart className="h-4 w-4" />,
    color: 'text-green-400',
    activeBg: 'bg-green-500/10',
    activeBorder: 'border-green-500',
  },
  {
    key: 'aerobic',
    label: 'Aerobic',
    zone: 'Z2',
    tag: 'aerobic',
    icon: <Wind className="h-4 w-4" />,
    color: 'text-sky-400',
    activeBg: 'bg-sky-500/10',
    activeBorder: 'border-sky-500',
  },
  {
    key: 'tempo',
    label: 'Tempo',
    zone: 'Z3',
    tag: 'tempo',
    icon: <Activity className="h-4 w-4" />,
    color: 'text-amber-400',
    activeBg: 'bg-amber-500/10',
    activeBorder: 'border-amber-500',
  },
  {
    key: 'threshold',
    label: 'Threshold',
    zone: 'Z4',
    tag: 'threshold',
    icon: <Flame className="h-4 w-4" />,
    color: 'text-orange-400',
    activeBg: 'bg-orange-500/10',
    activeBorder: 'border-orange-500',
  },
  {
    key: 'vo2max',
    label: 'VO2max',
    zone: 'Z5',
    tag: 'vo2max',
    icon: <Zap className="h-4 w-4" />,
    color: 'text-red-400',
    activeBg: 'bg-red-500/10',
    activeBorder: 'border-red-500',
  },
];

// ── Collection categories ───────────────────────────────────────

export interface CollectionCategory {
  key: string;
  label: string;
  tags: string[];
  icon: ReactNode;
  color: string;
  activeBg: string;
  activeBorder: string;
}

const COLLECTION_CATEGORIES: CollectionCategory[] = [
  {
    key: 'pete-plan',
    label: 'Pete Plan',
    tags: ['pete-plan'],
    icon: <BookOpen className="h-4 w-4" />,
    color: 'text-indigo-400',
    activeBg: 'bg-indigo-500/10',
    activeBorder: 'border-indigo-500',
  },
  {
    key: 'ftp-builder',
    label: 'FTP Builder',
    tags: ['ftp-builder'],
    icon: <BookOpen className="h-4 w-4" />,
    color: 'text-violet-400',
    activeBg: 'bg-violet-500/10',
    activeBorder: 'border-violet-500',
  },
  {
    key: '2k-race-prep',
    label: '2K Race Prep',
    tags: ['2k-race-prep'],
    icon: <BookOpen className="h-4 w-4" />,
    color: 'text-rose-400',
    activeBg: 'bg-rose-500/10',
    activeBorder: 'border-rose-500',
  },
  {
    key: 'wods',
    label: 'WODs',
    tags: ['wod', 'challenge'],
    icon: <Flame className="h-4 w-4" />,
    color: 'text-orange-400',
    activeBg: 'bg-orange-500/10',
    activeBorder: 'border-orange-500',
  },
  {
    key: 'classics',
    label: 'Classics',
    tags: ['classic', 'benchmark', 'test'],
    icon: <BookOpen className="h-4 w-4" />,
    color: 'text-cyan-400',
    activeBg: 'bg-cyan-500/10',
    activeBorder: 'border-cyan-500',
  },
];

// ── Filter state ────────────────────────────────────────────────

export interface CategoryFilters {
  duration: DurationBucket | null;
  zones: string[];
  collection: string | null;
}

export const EMPTY_FILTERS: CategoryFilters = {
  duration: null,
  zones: [],
  collection: null,
};

export function hasActiveFilters(filters: CategoryFilters): boolean {
  return filters.duration !== null || filters.zones.length > 0 || filters.collection !== null;
}

/** Get the collection category definition by key. */
export function getCollectionByKey(key: string): CollectionCategory | undefined {
  return COLLECTION_CATEGORIES.find((c) => c.key === key);
}

// ── Component ───────────────────────────────────────────────────

interface CategoryCardsProps {
  filters: CategoryFilters;
  onFiltersChange: (filters: CategoryFilters) => void;
}

export function CategoryCards({ filters, onFiltersChange }: CategoryCardsProps) {
  const toggleDuration = (key: DurationBucket) => {
    onFiltersChange({
      ...filters,
      duration: filters.duration === key ? null : key,
    });
  };

  const toggleZone = (tag: string) => {
    const next = filters.zones.includes(tag)
      ? filters.zones.filter((z) => z !== tag)
      : [...filters.zones, tag];
    onFiltersChange({ ...filters, zones: next });
  };

  const toggleCollection = (key: string) => {
    onFiltersChange({
      ...filters,
      collection: filters.collection === key ? null : key,
    });
  };

  return (
    <div className="space-y-3">
      {/* Duration row */}
      <div>
        <span className="mb-1.5 block text-[10px] uppercase tracking-wider text-gray-500">Duration</span>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {DURATION_CATEGORIES.map((cat) => {
            const active = filters.duration === cat.key;
            return (
              <button
                key={cat.key}
                type="button"
                onClick={() => toggleDuration(cat.key)}
                className={`flex cursor-pointer items-center gap-2.5 rounded-xl border px-3 py-2.5 text-left transition-colors ${
                  active
                    ? `${cat.activeBorder} ${cat.activeBg}`
                    : 'border-gray-800 bg-gray-900 hover:border-gray-700'
                }`}
              >
                <span className={cat.color}>{cat.icon}</span>
                <div>
                  <div className={`text-sm font-semibold ${active ? cat.color : 'text-white'}`}>
                    {cat.label}
                  </div>
                  <div className="text-xs text-gray-500">{cat.subtitle}</div>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Zone row */}
      <div>
        <span className="mb-1.5 block text-[10px] uppercase tracking-wider text-gray-500">Zone</span>
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-5">
          {ZONE_CATEGORIES.map((cat) => {
            const active = filters.zones.includes(cat.tag);
            return (
              <button
                key={cat.key}
                type="button"
                onClick={() => toggleZone(cat.tag)}
                className={`flex cursor-pointer flex-col items-center gap-0.5 rounded-xl border px-2 py-2.5 text-center transition-colors ${
                  active
                    ? `${cat.activeBorder} ${cat.activeBg}`
                    : 'border-gray-800 bg-gray-900 hover:border-gray-700'
                }`}
              >
                <span className={cat.color}>{cat.icon}</span>
                <span className={`text-xs font-semibold ${active ? cat.color : 'text-white'}`}>
                  {cat.label}
                </span>
                <span className="text-[10px] text-gray-500">{cat.zone}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Collection row */}
      <div>
        <span className="mb-1.5 block text-[10px] uppercase tracking-wider text-gray-500">Collection</span>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-5">
          {COLLECTION_CATEGORIES.map((cat) => {
            const active = filters.collection === cat.key;
            return (
              <button
                key={cat.key}
                type="button"
                onClick={() => toggleCollection(cat.key)}
                className={`flex cursor-pointer items-center gap-2 rounded-xl border px-3 py-2.5 text-left transition-colors ${
                  active
                    ? `${cat.activeBorder} ${cat.activeBg}`
                    : 'border-gray-800 bg-gray-900 hover:border-gray-700'
                }`}
              >
                <span className={cat.color}>{cat.icon}</span>
                <span className={`text-sm font-semibold ${active ? cat.color : 'text-white'}`}>
                  {cat.label}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
