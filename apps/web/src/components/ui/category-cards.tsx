'use client';

import { Clock, Heart, Wind, Activity, Flame, Zap, User, Trophy, Ruler } from 'lucide-react';
import type { ReactNode } from 'react';

// ── Duration categories ─────────────────────────────────────────

export type DurationBucket = 'under30' | '30to60' | 'over60';

// ── Distance categories ────────────────────────────────────────

export type DistanceBucket = 'under2k' | '2to5k' | '5to10k' | 'over10k';

// ── Filter state ────────────────────────────────────────────────

export interface CategoryFilters {
  duration: DurationBucket | null;
  distance: DistanceBucket | null;
  zones: string[];
  collection: string | null;
  mine: boolean;
}

export const EMPTY_FILTERS: CategoryFilters = {
  duration: null,
  distance: null,
  zones: [],
  collection: null,
  mine: false,
};

export function hasActiveFilters(filters: CategoryFilters): boolean {
  return (
    filters.duration !== null ||
    filters.distance !== null ||
    filters.zones.length > 0 ||
    filters.collection !== null ||
    filters.mine
  );
}

// ── Collections ─────────────────────────────────────────────────

export interface CollectionCategory {
  key: string;
  label: string;
  tags: string[];
}

const COLLECTION_CATEGORIES: CollectionCategory[] = [
  { key: 'pete-plan', label: 'Pete Plan', tags: ['pete-plan'] },
  { key: 'ftp-builder', label: 'FTP Builder', tags: ['ftp-builder'] },
  { key: '2k-race-prep', label: '2K Race Prep', tags: ['2k-race-prep'] },
  { key: 'return-to-rowing', label: 'Return to Rowing', tags: ['return-to-rowing'] },
  { key: 'wods', label: 'WODs', tags: ['wod', 'challenge'] },
  { key: 'classics', label: 'Classics', tags: ['classic', 'benchmark', 'test'] },
];

export function getCollectionByKey(key: string): CollectionCategory | undefined {
  return COLLECTION_CATEGORIES.find((c) => c.key === key);
}

// ── Unified category items ──────────────────────────────────────

type CategoryType = 'duration' | 'distance' | 'zone' | 'collection' | 'special';

interface CategoryItem {
  type: CategoryType;
  key: string;
  label: string;
  subtitle: string;
  icon: ReactNode;
  /** Background gradient for the card */
  bg: string;
  /** Ring color when active */
  ring: string;
}

const ALL_CATEGORIES: CategoryItem[] = [
  // Duration — cool blue-gray tones
  {
    type: 'duration', key: 'under30', label: 'Under 30m', subtitle: 'Quick hits',
    icon: <Clock className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-sky-600 to-sky-800',
    ring: 'ring-sky-400',
  },
  {
    type: 'duration', key: '30to60', label: '30–60m', subtitle: 'Sweet spot',
    icon: <Clock className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-emerald-600 to-emerald-800',
    ring: 'ring-emerald-400',
  },
  {
    type: 'duration', key: 'over60', label: '60+ min', subtitle: 'Long haul',
    icon: <Clock className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-amber-600 to-amber-800',
    ring: 'ring-amber-400',
  },
  // Distance — teal tones
  {
    type: 'distance', key: 'under2k', label: '≤2k', subtitle: 'Sprint',
    icon: <Ruler className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-teal-600 to-teal-800',
    ring: 'ring-teal-400',
  },
  {
    type: 'distance', key: '2to5k', label: '2–5k', subtitle: 'Short',
    icon: <Ruler className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-cyan-600 to-cyan-800',
    ring: 'ring-cyan-400',
  },
  {
    type: 'distance', key: '5to10k', label: '5–10k', subtitle: 'Mid',
    icon: <Ruler className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-teal-700 to-emerald-900',
    ring: 'ring-teal-400',
  },
  {
    type: 'distance', key: 'over10k', label: '10k+', subtitle: 'Long',
    icon: <Ruler className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-emerald-700 to-teal-900',
    ring: 'ring-emerald-400',
  },
  // Zones — match HR zone colors
  {
    type: 'zone', key: 'recovery', label: 'Recovery', subtitle: 'Z1',
    icon: <Heart className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-green-600 to-green-800',
    ring: 'ring-green-400',
  },
  {
    type: 'zone', key: 'aerobic', label: 'Aerobic', subtitle: 'Z2',
    icon: <Wind className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-sky-500 to-blue-700',
    ring: 'ring-sky-400',
  },
  {
    type: 'zone', key: 'tempo', label: 'Tempo', subtitle: 'Z3',
    icon: <Activity className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-amber-500 to-amber-700',
    ring: 'ring-amber-400',
  },
  {
    type: 'zone', key: 'threshold', label: 'Threshold', subtitle: 'Z4',
    icon: <Flame className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-orange-500 to-orange-700',
    ring: 'ring-orange-400',
  },
  {
    type: 'zone', key: 'vo2max', label: 'VO2max', subtitle: 'Z5',
    icon: <Zap className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-red-500 to-red-700',
    ring: 'ring-red-400',
  },
  // Collections
  {
    type: 'collection', key: 'wods', label: 'WODs', subtitle: 'Challenges',
    icon: <Trophy className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-orange-600 to-orange-800',
    ring: 'ring-orange-400',
  },
  // Special
  {
    type: 'special', key: 'mine', label: 'My Workouts', subtitle: 'Personal',
    icon: <User className="h-7 w-7" />,
    bg: 'bg-gradient-to-br from-gray-600 to-gray-800',
    ring: 'ring-gray-400',
  },
];

// ── Component ───────────────────────────────────────────────────

interface CategoryCardsProps {
  filters: CategoryFilters;
  onFiltersChange: (filters: CategoryFilters) => void;
  userId?: string | null;
}

function isCatActive(cat: CategoryItem, filters: CategoryFilters): boolean {
  switch (cat.type) {
    case 'duration': return filters.duration === cat.key;
    case 'distance': return filters.distance === cat.key;
    case 'zone': return filters.zones.includes(cat.key);
    case 'collection': return filters.collection === cat.key;
    case 'special': return cat.key === 'mine' && filters.mine;
  }
}

export function CategoryCards({ filters, onFiltersChange, userId }: CategoryCardsProps) {
  const visibleCategories = ALL_CATEGORIES.filter((cat) => {
    if (cat.type === 'special' && cat.key === 'mine' && !userId) return false;
    return true;
  });
  const toggle = (cat: CategoryItem) => {
    const reset: CategoryFilters = { ...EMPTY_FILTERS };
    switch (cat.type) {
      case 'duration':
        onFiltersChange({ ...reset, duration: filters.duration === cat.key ? null : cat.key as DurationBucket });
        break;
      case 'distance':
        onFiltersChange({ ...reset, distance: filters.distance === cat.key ? null : cat.key as DistanceBucket });
        break;
      case 'zone':
        onFiltersChange({ ...reset, zones: filters.zones.includes(cat.key) ? [] : [cat.key] });
        break;
      case 'collection':
        onFiltersChange({ ...reset, collection: filters.collection === cat.key ? null : cat.key });
        break;
      case 'special':
        if (cat.key === 'mine') {
          onFiltersChange({ ...reset, mine: !filters.mine });
        }
        break;
    }
  };

  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
      {visibleCategories.map((cat) => {
        const active = isCatActive(cat, filters);
        return (
          <button
            key={`${cat.type}-${cat.key}`}
            type="button"
            onClick={() => toggle(cat)}
            className={`flex aspect-square cursor-pointer flex-col items-center justify-center gap-2 rounded-xl transition-all ${cat.bg} ${
              active ? `ring-2 ${cat.ring} scale-95` : 'hover:scale-[1.02]'
            }`}
          >
            <span className="text-white/90">{cat.icon}</span>
            <span className="text-sm font-bold text-white">{cat.label}</span>
            <span className="text-xs text-white/60">{cat.subtitle}</span>
          </button>
        );
      })}
    </div>
  );
}
