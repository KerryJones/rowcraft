'use client';

import { useState, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import type { Workout } from '@/lib/types';
import { WorkoutCard } from '@/components/ui/workout-card';
import { WodCard } from '@/components/ui/wod-card';
import { Search, Plus } from 'lucide-react';

type Tab = 'all' | 'mine' | 'community';

function getDeterministicWod(workouts: Workout[]): Workout | null {
  if (workouts.length === 0) return null;
  // Deterministic daily pick: use date as seed
  const today = new Date();
  const dayOfYear = Math.floor(
    (today.getTime() - new Date(today.getFullYear(), 0, 0).getTime()) / 86400000
  );
  // Simple shuffle with seed
  const shuffled = [...workouts].sort((a, b) => {
    const hashA = (dayOfYear * 2654435761 + a.id.charCodeAt(0)) >>> 0;
    const hashB = (dayOfYear * 2654435761 + b.id.charCodeAt(0)) >>> 0;
    return hashA - hashB;
  });
  return shuffled[0];
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

  // Collect all tags
  const allTags = useMemo(() => {
    const tagSet = new Set<string>();
    workouts.forEach((w) => w.tags.forEach((t) => tagSet.add(t)));
    return Array.from(tagSet).sort();
  }, [workouts]);

  // Filter workouts
  const filtered = useMemo(() => {
    return workouts.filter((w) => {
      // Tab filter
      if (tab === 'mine' && w.author_id !== userId) return false;
      if (tab === 'community' && w.author_id === userId) return false;

      // Search filter
      if (search) {
        const q = search.toLowerCase();
        const matchesTitle = w.title.toLowerCase().includes(q);
        const matchesDesc = (w.description ?? '').toLowerCase().includes(q);
        const matchesTags = w.tags.some((t) => t.toLowerCase().includes(q));
        if (!matchesTitle && !matchesDesc && !matchesTags) return false;
      }

      // Tag filter
      if (selectedTag && !w.tags.includes(selectedTag)) return false;

      return true;
    });
  }, [workouts, tab, search, selectedTag, userId]);

  const publicWorkouts = workouts.filter((w) => w.is_public);
  const wod = getDeterministicWod(publicWorkouts);

  const tabs: { key: Tab; label: string }[] = [
    { key: 'all', label: 'All' },
    ...(userId ? [{ key: 'mine' as Tab, label: 'Mine' }] : []),
    { key: 'community', label: 'Community' },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
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
          <WodCard workout={wod} onClick={() => router.push(`/workouts/${wod.id}`)} />
        </div>
      )}

      {/* Search + Tabs */}
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center">
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

      {/* Workout grid */}
      {filtered.length === 0 ? (
        <div className="py-16 text-center text-gray-500">
          No workouts found. Try adjusting your search or filters.
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
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
