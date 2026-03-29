'use client';

import { useState } from 'react';
import { Search } from 'lucide-react';

interface WorkoutOption {
  id: string;
  title: string;
}

interface WorkoutPickerProps {
  workouts: WorkoutOption[];
  selectedId: string | null;
  onChange: (id: string) => void;
  placeholder?: string;
}

export function WorkoutPicker({ workouts, selectedId, onChange, placeholder }: WorkoutPickerProps) {
  const [search, setSearch] = useState('');
  const [open, setOpen] = useState(false);

  const filtered = workouts.filter((w) =>
    w.title.toLowerCase().includes(search.toLowerCase())
  );

  const selected = workouts.find((w) => w.id === selectedId);

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen(!open)}
        className="flex w-full cursor-pointer items-center justify-between rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-left text-sm text-white"
      >
        <span className={selected ? 'text-white' : 'text-gray-500'}>
          {selected?.title ?? placeholder ?? 'Select workout...'}
        </span>
        <Search className="h-4 w-4 text-gray-500" />
      </button>

      {open && (
        <div className="absolute z-10 mt-1 w-full rounded-lg border border-gray-700 bg-gray-800 shadow-lg">
          <div className="border-b border-gray-700 p-2">
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search workouts..."
              className="w-full rounded border border-gray-600 bg-gray-900 px-2 py-1.5 text-sm text-white placeholder-gray-500 focus:outline-none"
              autoFocus
            />
          </div>
          <div className="max-h-48 overflow-y-auto py-1">
            {filtered.length === 0 ? (
              <div className="px-3 py-2 text-sm text-gray-500">No workouts found</div>
            ) : (
              filtered.map((w) => (
                <button
                  key={w.id}
                  type="button"
                  onClick={() => {
                    onChange(w.id);
                    setOpen(false);
                    setSearch('');
                  }}
                  className={`w-full cursor-pointer px-3 py-2 text-left text-sm transition-colors hover:bg-gray-700 ${
                    w.id === selectedId ? 'bg-gray-700 text-white' : 'text-gray-300'
                  }`}
                >
                  {w.title}
                </button>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}
