'use client';

import { useState, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import type { Workout } from '@/lib/types';
import { WorkoutCard } from '@/components/ui/workout-card';
import { WodCard } from '@/components/ui/wod-card';
import { Search, Plus } from 'lucide-react';

type Tab = 'all' | 'mine' | 'community';
type SortKey = 'newest' | 'most_forked' | 'duration';

function djb2(str: string): number {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) + hash + str.charCodeAt(i)) >>> 0;
  }
  return hash;
}

function getDeterministicWod(workouts: Workout[], seed: number): Workout | null {
  if (workouts.length === 0) return null;
  const shuffled = [...workouts].sort((a, b) => {
    const hashA = (seed * 2654435761 + djb2(a.id)) >>> 0;
    const hashB = (seed * 2654435761 + djb2(b.id)) >>> 0;
    return hashA - hashB;
  });
  return shuffled[0];
}

function getDaysSinceEpoch(): number {
  const now = new Date();
  const epoch = Date.UTC(2025, 0, 1);
  const current = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  return Math.floor((current - epoch) / 86400000);
}

interface WorkoutsClientProps {
  workouts: Workout[];
  userId: string | null;
}

export function WorkoutsClient({ workouts, userId }: WorkoutsClientProps) {
  const router = useRouter();
  const [search, setSearch] = useState('');
  const [tab, setTab] = useState<Tab>('all');
  const [selectedTag, setSelectedTag] = useState<string | null>(null);
  const [sortKey, setSortKey] = useState<SortKey>('newest');
  const [wodSeed, setWodSeed] = useState(getDaysSinceEpoch);

  // Collect all tags
  const allTags = useMemo(() => {
    const tagSet = new Set<string>();
    workouts.forEach((w) => w.tags.forEach((t) => tagSet.add(t)));
    return Array.from(tagSet).sort();
  }, [workouts]);

  const publicWorkouts = workouts.filter((w) => w.is_public);
  const wod = getDeterministicWod(publicWorkouts, wodSeed);

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
      if (selectedTag && !w.tags.includes(selectedTag)) return false;
      return true;
    });

    // Sort
    if (sortKey === 'newest') {
      result.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    } else if (sortKey === 'most_forked') {
      result.sort((a, b) => b.fork_count - a.fork_count);
    } else if (sortKey === 'duration') {
      const getTime = (w: Workout) => {
        let t = 0;
        for (const s of w.segments) {
          if (s.duration_type === 'time') t += s.duration_value * (s.repeat || 1);
        }
        return t;
      };
      result.sort((a, b) => getTime(b) - getTime(a));
    }

    return result;
  }, [workouts, tab, search, selectedTag, userId, sortKey, wod]);

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
            onShuffle={() => setWodSeed((s) => s + 1)}
            onView={() => router.push(`/workouts/${wod.id}`)}
          />
        </div>
      )}

      {/* Search + Tabs */}
      <div className="mb-4 flex flex-col gap-4 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search workouts..."
            className="w-full rounded-lg border border-gray-700 bg-gray-800 py-2.5 pl-10 pr-4 text-sm text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          />
        </div>

        <div className="flex gap-1 rounded-lg bg-gray-900 p-1">
          {tabs.map((t) => (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
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

      {/* Sort options */}
      <div className="mb-4 flex items-center gap-2">
        <span className="text-xs text-gray-500">Sort:</span>
        {sortOptions.map((opt) => (
          <button
            key={opt.key}
            onClick={() => setSortKey(opt.key)}
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

      {/* Tag filter chips */}
      {allTags.length > 0 && (
        <div className="mb-6 flex flex-wrap gap-2">
          <button
            onClick={() => setSelectedTag(null)}
            className={`cursor-pointer rounded-full px-3 py-1 text-xs font-medium transition-colors ${
              selectedTag === null
                ? 'bg-blue-600 text-white'
                : 'bg-gray-800 text-gray-400 hover:text-white'
            }`}
          >
            All
          </button>
          {allTags.map((tag) => (
            <button
              key={tag}
              onClick={() => setSelectedTag(selectedTag === tag ? null : tag)}
              className={`cursor-pointer rounded-full px-3 py-1 text-xs font-medium transition-colors ${
                selectedTag === tag
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-800 text-gray-400 hover:text-white'
              }`}
            >
              {tag}
            </button>
          ))}
        </div>
      )}

      {/* Workout list — single column */}
      {filtered.length === 0 ? (
        <div className="py-16 text-center text-gray-500">
          No workouts found. Try adjusting your search or filters.
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {filtered.map((workout) => (
            <WorkoutCard
              key={workout.id}
              workout={workout}
              onClick={() => router.push(`/workouts/${workout.id}`)}
            />
          ))}
        </div>
      )}
    </div>
  );
}
