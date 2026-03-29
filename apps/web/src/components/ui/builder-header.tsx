'use client';

import type { WorkoutType } from '@/lib/types';

const WORKOUT_TYPES: { value: WorkoutType; label: string }[] = [
  { value: 'single_time', label: 'Single Time' },
  { value: 'single_distance', label: 'Single Distance' },
  { value: 'intervals', label: 'Intervals' },
  { value: 'variable_intervals', label: 'Variable Intervals' },
];

interface BuilderHeaderProps {
  title: string;
  description: string;
  workoutType: WorkoutType;
  tags: string[];
  isPublic: boolean;
  onTitleChange: (title: string) => void;
  onDescriptionChange: (description: string) => void;
  onWorkoutTypeChange: (type: WorkoutType) => void;
  onTagsChange: (tags: string[]) => void;
  onPublicChange: (isPublic: boolean) => void;
}

export function BuilderHeader({
  title,
  description,
  workoutType,
  tags,
  isPublic,
  onTitleChange,
  onDescriptionChange,
  onWorkoutTypeChange,
  onTagsChange,
  onPublicChange,
}: BuilderHeaderProps) {
  return (
    <div className="space-y-4">
      {/* Title */}
      <div>
        <label className="mb-1 block text-sm font-medium text-gray-400">Title</label>
        <input
          type="text"
          value={title}
          onChange={(e) => onTitleChange(e.target.value)}
          placeholder="Workout title"
          className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
        />
      </div>

      {/* Description */}
      <div>
        <label className="mb-1 block text-sm font-medium text-gray-400">Description</label>
        <textarea
          value={description}
          onChange={(e) => onDescriptionChange(e.target.value)}
          placeholder="Describe the workout..."
          rows={2}
          className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
        />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        {/* Workout Type */}
        <div>
          <label className="mb-1 block text-sm font-medium text-gray-400">Workout Type</label>
          <select
            value={workoutType}
            onChange={(e) => onWorkoutTypeChange(e.target.value as WorkoutType)}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2.5 text-sm text-white"
          >
            {WORKOUT_TYPES.map((t) => (
              <option key={t.value} value={t.value}>{t.label}</option>
            ))}
          </select>
        </div>

        {/* Tags */}
        <div>
          <label className="mb-1 block text-sm font-medium text-gray-400">Tags (comma separated)</label>
          <input
            type="text"
            value={tags.join(', ')}
            onChange={(e) =>
              onTagsChange(
                e.target.value
                  .split(',')
                  .map((t) => t.trim())
                  .filter(Boolean)
              )
            }
            placeholder="endurance, 2k, steady state"
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2.5 text-sm text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          />
        </div>

        {/* Public toggle */}
        <div className="flex items-end">
          <label className="flex cursor-pointer items-center gap-2">
            <input
              type="checkbox"
              checked={isPublic}
              onChange={(e) => onPublicChange(e.target.checked)}
              className="h-4 w-4 rounded border-gray-600 bg-gray-800 text-blue-600 focus:ring-blue-500"
            />
            <span className="text-sm text-gray-400">Public workout</span>
          </label>
        </div>
      </div>
    </div>
  );
}
