'use client';

import { useState, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import type { Workout } from '@/lib/types';
import { WorkoutCard } from '@/components/ui/workout-card';
import { CategoryCards, EMPTY_FILTERS, hasActiveFilters, getCollectionByKey } from '@/components/ui/category-cards';
import type { CategoryFilters, DurationBucket, DistanceBucket } from '@/components/ui/category-cards';
import { Pagination } from '@/components/ui/pagination';
import { computeTotalDistance, estimateTotalMinutes } from '@/lib/utils/workout';
import { Search, Plus, ArrowLeft } from 'lucide-react';

type SortKey = 'newest' | 'most_forked' | 'duration';

const PAGE_SIZE = 12;

function matchesDuration(workout: Workout, bucket: DurationBucket): boolean {
  const minutes = estimateTotalMinutes(workout.segments);
  switch (bucket) {
    case 'under30': return minutes < 30;
    case '30to60': return minutes >= 30 && minutes < 60;
    case 'over60': return minutes >= 60;
  }
}

function matchesDistance(workout: Workout, bucket: DistanceBucket): boolean {
  const meters = computeTotalDistance(workout.segments);
  if (meters == null) return false; // exclude time-only workouts
  switch (bucket) {
    case 'under2k':  return meters < 2000;
    case '2to5k':    return meters >= 2000 && meters < 5000;
    case '5to10k':   return meters >= 5000 && meters < 10000;
    case 'over10k':  return meters >= 10000;
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
  const [filters, setFilters] = useState<CategoryFilters>(EMPTY_FILTERS);
  const [sortKey, setSortKey] = useState<SortKey>('newest');
  const [page, setPage] = useState(1);

  const isBrowsing = hasActiveFilters(filters) || search.length > 0;

  // Filter workouts
  const filtered = useMemo(() => {
    const result = workouts.filter((w) => {
      if (filters.mine) {
        if (!userId) return false;
        if (w.author_id !== userId) return false;
      }
      if (search) {
        const q = search.toLowerCase();
        const matchesTitle = w.title.toLowerCase().includes(q);
        const matchesDesc = (w.description ?? '').toLowerCase().includes(q);
        const matchesTags = w.tags.some((t) => t.toLowerCase().includes(q));
        if (!matchesTitle && !matchesDesc && !matchesTags) return false;
      }

      if (filters.duration && !matchesDuration(w, filters.duration)) return false;
      if (filters.distance && !matchesDistance(w, filters.distance)) return false;

      if (filters.zones.length > 0) {
        if (!filters.zones.some((z) => w.tags.includes(z))) return false;
      }

      if (filters.collection) {
        const col = getCollectionByKey(filters.collection);
        if (col && !col.tags.some((t) => w.tags.includes(t))) return false;
      }

      return true;
    });

    if (sortKey === 'newest') {
      result.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    } else if (sortKey === 'most_forked') {
      result.sort((a, b) => b.fork_count - a.fork_count);
    } else if (sortKey === 'duration') {
      result.sort((a, b) => estimateTotalMinutes(b.segments) - estimateTotalMinutes(a.segments));
    }

    return result;
  }, [workouts, search, filters, userId, sortKey]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const paginatedWorkouts = filtered.slice(
    (currentPage - 1) * PAGE_SIZE,
    currentPage * PAGE_SIZE,
  );

  const handleFiltersChange = (next: CategoryFilters) => {
    setFilters(next);
    setPage(1);
  };

  const backToCategories = () => {
    setFilters(EMPTY_FILTERS);
    setSearch('');
    setPage(1);
  };

  const sortOptions: { key: SortKey; label: string }[] = [
    { key: 'newest', label: 'Newest' },
    { key: 'most_forked', label: 'Most Forked' },
    { key: 'duration', label: 'Duration' },
  ];

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6">
      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        {isBrowsing ? (
          <button
            type="button"
            onClick={backToCategories}
            className="flex cursor-pointer items-center gap-2 text-gray-400 transition-colors hover:text-white"
          >
            <ArrowLeft className="h-5 w-5" />
            <h1 className="text-3xl font-bold text-white">Workouts</h1>
          </button>
        ) : (
          <h1 className="text-3xl font-bold text-white">Workouts</h1>
        )}
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

      {/* Landing state: categories */}
      {!isBrowsing && (
        <>
          {/* Search */}
          <div className="mb-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500" />
              <input
                type="text"
                value={search}
                onChange={(e) => { setSearch(e.target.value); setPage(1); }}
                placeholder="Search by name, tag, or description..."
                className="w-full rounded-lg border border-gray-700 bg-gray-800 py-2.5 pl-10 pr-4 text-sm text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
              />
            </div>
          </div>

          {/* Category cards */}
          <CategoryCards filters={filters} onFiltersChange={handleFiltersChange} userId={userId} />
        </>
      )}

      {/* Browse state: filtered results */}
      {isBrowsing && (
        <>
          {/* Search */}
          <div className="mb-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500" />
              <input
                type="text"
                value={search}
                onChange={(e) => { setSearch(e.target.value); setPage(1); }}
                placeholder="Search workouts..."
                className="w-full rounded-lg border border-gray-700 bg-gray-800 py-2.5 pl-10 pr-4 text-sm text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
              />
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

          {/* Workout grid */}
          {paginatedWorkouts.length === 0 ? (
            <div className="py-16 text-center text-gray-500">
              {filters.mine && !userId
                ? 'Please sign in to see your workouts.'
                : 'No workouts match your filters. Try adjusting or clearing them.'}
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
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

          <Pagination page={currentPage} totalPages={totalPages} onPageChange={setPage} />
        </>
      )}
    </div>
  );
}
