'use client';

import { useState, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import type { Workout } from '@/lib/types';
import { WorkoutCard } from '@/components/ui/workout-card';
import { WodCard } from '@/components/ui/wod-card';
import { CategoryCards, EMPTY_FILTERS, hasActiveFilters, getCollectionByKey } from '@/components/ui/category-cards';
import type { CategoryFilters, DurationBucket } from '@/components/ui/category-cards';
import { Pagination } from '@/components/ui/pagination';
import { estimateTotalMinutes } from '@/lib/utils/workout';
import { Search, Plus, X } from 'lucide-react';

type Tab = 'all' | 'mine' | 'community';
type SortKey = 'newest' | 'most_forked' | 'duration';

const PAGE_SIZE = 12;

function getDaysSinceEpoch(): number {
  const now = new Date();
  const epoch = Date.UTC(2025, 0, 1);
  const current = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  return Math.floor((current - epoch) / 86400000);
}

function matchesDuration(workout: Workout, bucket: DurationBucket): boolean {
  const minutes = estimateTotalMinutes(workout.segments);
  switch (bucket) {
    case 'under30': return minutes < 30;
    case '30to60': return minutes >= 30 && minutes < 60;
    case 'over60': return minutes >= 60;
  }
}

interface WorkoutsClientProps {
  workouts: Workout[];
  userId: string | null;
  ftpWatts?: number | null;
}

export function WorkoutsClient({ workouts, userId, ftpWatts }: WorkoutsClientProps) {
  const router = useRouter();
  const [search, setSearch] = useState('');
  const [tab, setTab] = useState<Tab>('all');
  const [filters, setFilters] = useState<CategoryFilters>(EMPTY_FILTERS);
  const [sortKey, setSortKey] = useState<SortKey>('newest');
  const [wodSeed, setWodSeed] = useState(getDaysSinceEpoch);
  const [page, setPage] = useState(1);

  const publicWorkouts = workouts.filter((w) => w.is_public);
  const wod = publicWorkouts.length > 0
    ? publicWorkouts[wodSeed % publicWorkouts.length]
    : null;

  // Filter workouts
  const filtered = useMemo(() => {
    const result = workouts.filter((w) => {
      // Exclude WOD from the main list to avoid duplication
      if (wod && w.id === wod.id) return false;
      if (tab === 'mine' && w.author_id !== userId) return false;
      if (tab === 'community' && w.author_id === userId) return false;
      if (search) {
        const q = search.toLowerCase();
        const matchesTitle = w.title.toLowerCase().includes(q);
        const matchesDesc = (w.description ?? '').toLowerCase().includes(q);
        const matchesTags = w.tags.some((t) => t.toLowerCase().includes(q));
        if (!matchesTitle && !matchesDesc && !matchesTags) return false;
      }

      // Duration filter
      if (filters.duration && !matchesDuration(w, filters.duration)) return false;

      // Zone filter (OR within zones)
      if (filters.zones.length > 0) {
        if (!filters.zones.some((z) => w.tags.includes(z))) return false;
      }

      // Collection filter
      if (filters.collection) {
        const col = getCollectionByKey(filters.collection);
        if (col && !col.tags.some((t) => w.tags.includes(t))) return false;
      }

      return true;
    });

    // Sort
    if (sortKey === 'newest') {
      result.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    } else if (sortKey === 'most_forked') {
      result.sort((a, b) => b.fork_count - a.fork_count);
    } else if (sortKey === 'duration') {
      result.sort((a, b) => estimateTotalMinutes(b.segments) - estimateTotalMinutes(a.segments));
    }

    return result;
  }, [workouts, tab, search, filters, userId, sortKey, wod]);

  // Pagination
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const paginatedWorkouts = filtered.slice(
    (currentPage - 1) * PAGE_SIZE,
    currentPage * PAGE_SIZE,
  );

  // Reset page when filters change
  const handleFiltersChange = (next: CategoryFilters) => {
    setFilters(next);
    setPage(1);
  };

  const clearFilters = () => {
    setFilters(EMPTY_FILTERS);
    setPage(1);
  };

  const tabs: { key: Tab; label: string }[] = [
    { key: 'all', label: 'All' },
    ...(userId ? [{ key: 'mine' as Tab, label: 'Mine' }] : []),
    { key: 'community', label: 'Community' },
  ];

  const sortOptions: { key: SortKey; label: string }[] = [
    { key: 'newest', label: 'Newest' },
    { key: 'most_forked', label: 'Most Forked' },
    { key: 'duration', label: 'Duration' },
  ];

  // Build active filter chips for display
  const activeChips: { key: string; label: string; onRemove: () => void }[] = [];
  if (filters.duration) {
    const labels: Record<DurationBucket, string> = {
      under30: 'Under 30 min',
      '30to60': '30–60 min',
      over60: '60+ min',
    };
    activeChips.push({
      key: `duration:${filters.duration}`,
      label: labels[filters.duration],
      onRemove: () => handleFiltersChange({ ...filters, duration: null }),
    });
  }
  for (const zone of filters.zones) {
    activeChips.push({
      key: `zone:${zone}`,
      label: zone.charAt(0).toUpperCase() + zone.slice(1),
      onRemove: () => handleFiltersChange({ ...filters, zones: filters.zones.filter((z) => z !== zone) }),
    });
  }
  if (filters.collection) {
    const col = getCollectionByKey(filters.collection);
    activeChips.push({
      key: `collection:${filters.collection}`,
      label: col?.label ?? filters.collection,
      onRemove: () => handleFiltersChange({ ...filters, collection: null }),
    });
  }

  return (
    <div className="mx-auto max-w-[900px] px-4 py-8 sm:px-6">
      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <h1 className="text-3xl font-bold text-white">Workouts</h1>
        {userId && (
          <Link
            href="/builder"
            className="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-500"
          >
            <Plus className="h-4 w-4" />
            New Workout
          </Link>
        )}
      </div>

      {/* WOD */}
      {wod && (
        <div className="mb-8">
          <WodCard
            workout={wod}
            canShuffle={publicWorkouts.length > 1}
            onShuffle={() => setWodSeed((s) => s + 1)}
            onView={() => router.push(`/workouts/${wod.id}`)}
            ftpWatts={ftpWatts}
          />
        </div>
      )}

      {/* Category cards */}
      <div className="mb-6">
        <CategoryCards filters={filters} onFiltersChange={handleFiltersChange} />
      </div>

      {/* Active filter chips */}
      {activeChips.length > 0 && (
        <div className="mb-4 flex flex-wrap items-center gap-2">
          {activeChips.map((chip) => (
            <button
              key={chip.key}
              type="button"
              onClick={chip.onRemove}
              className="flex cursor-pointer items-center gap-1 rounded-full bg-blue-600/20 px-2.5 py-1 text-xs font-medium text-blue-400 transition-colors hover:bg-blue-600/30"
            >
              {chip.label}
              <X className="h-3 w-3" />
            </button>
          ))}
          <button
            type="button"
            onClick={clearFilters}
            className="cursor-pointer text-xs text-gray-500 transition-colors hover:text-white"
          >
            Clear all
          </button>
        </div>
      )}

      {/* Search + Tabs */}
      <div className="mb-4 flex flex-col gap-4 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500" />
          <input
            type="text"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            placeholder="Search workouts..."
            className="w-full rounded-lg border border-gray-700 bg-gray-800 py-2.5 pl-10 pr-4 text-sm text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          />
        </div>

        <div className="flex gap-1 rounded-lg bg-gray-900 p-1">
          {tabs.map((t) => (
            <button
              key={t.key}
              onClick={() => { setTab(t.key); setPage(1); }}
              className={`cursor-pointer rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
                tab === t.key
                  ? 'bg-gray-800 text-white'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
      </div>

      {/* Sort options + result count */}
      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-xs text-gray-500">Sort:</span>
          {sortOptions.map((opt) => (
            <button
              key={opt.key}
              onClick={() => { setSortKey(opt.key); setPage(1); }}
              className={`cursor-pointer rounded-full px-3 py-1 text-xs font-medium transition-colors ${
                sortKey === opt.key
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-800 text-gray-400 hover:text-white'
              }`}
            >
              {opt.label}
            </button>
          ))}
        </div>
        <span className="text-xs text-gray-500">
          {filtered.length} workout{filtered.length !== 1 ? 's' : ''}
        </span>
      </div>

      {/* Workout list */}
      {paginatedWorkouts.length === 0 ? (
        <div className="py-16 text-center text-gray-500">
          {hasActiveFilters(filters) || search
            ? 'No workouts match your filters. Try adjusting or clearing them.'
            : 'No workouts found.'}
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {paginatedWorkouts.map((workout) => (
            <WorkoutCard
              key={workout.id}
              workout={workout}
              onClick={() => router.push(`/workouts/${workout.id}`)}
              ftpWatts={ftpWatts}
            />
          ))}
        </div>
      )}

      {/* Pagination */}
      <Pagination page={currentPage} totalPages={totalPages} onPageChange={setPage} />
    </div>
  );
}
