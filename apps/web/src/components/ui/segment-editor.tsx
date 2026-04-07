'use client';

import { Copy } from 'lucide-react';
import type { WorkoutSegment, DurationType } from '@/lib/types';
import { formatPace } from '@/lib/utils/format';
import { resolveIntensityToPace, getEffectiveFtp, formatWatts, intensityToWatts, intensityToHrZone, HR_ZONES } from '@/lib/utils/ftp';

const DURATION_TYPES: { value: DurationType; label: string }[] = [
  { value: 'time', label: 'Time (seconds)' },
  { value: 'distance', label: 'Distance (meters)' },
  { value: 'calories', label: 'Calories' },
];

const HR_ZONE_BADGE: Record<number, string> = {
  1: 'bg-green-500/20 text-green-400',
  2: 'bg-blue-500/20 text-blue-400',
  3: 'bg-yellow-500/20 text-yellow-400',
  4: 'bg-orange-500/20 text-orange-400',
  5: 'bg-red-500/20 text-red-400',
};

interface SegmentEditorProps {
  segment: WorkoutSegment;
  onChange: (segment: WorkoutSegment) => void;
  onRemove: () => void;
  onDuplicate?: () => void;
  ftpWatts?: number | null;
}

export function SegmentEditor({ segment, onChange, onRemove, onDuplicate, ftpWatts }: SegmentEditorProps) {
  const ftp = getEffectiveFtp(ftpWatts ?? null);

  function updateField<K extends keyof WorkoutSegment>(key: K, value: WorkoutSegment[K]) {
    const updated = { ...segment, [key]: value };
    // Auto-derive hr_zone from intensity whenever intensity changes
    if (key === 'target_intensity') {
      updated.target_hr_zone = intensityToHrZone(value as number | null);
    }
    onChange(updated);
  }

  // Resolve current intensity to pace/watts for preview
  const preview = segment.target_intensity
    ? (() => {
        const pace = resolveIntensityToPace(segment.target_intensity, ftp);
        return { pace: formatPace(pace), watts: formatWatts(intensityToWatts(segment.target_intensity, ftp)) };
      })()
    : null;

  const derivedZone = segment.target_hr_zone;

  return (
    <div className="space-y-3 rounded-lg border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <h4 className="text-sm font-medium text-white">Edit Segment</h4>
          {derivedZone != null && (
            <span className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${HR_ZONE_BADGE[derivedZone] ?? 'bg-gray-700 text-gray-300'}`}>
              Z{derivedZone} · {HR_ZONES[derivedZone - 1]?.label}
            </span>
          )}
        </div>
        <div className="flex items-center gap-3">
          {onDuplicate && (
            <button
              type="button"
              onClick={onDuplicate}
              className="flex cursor-pointer items-center gap-1 text-xs text-gray-400 hover:text-gray-300"
            >
              <Copy className="h-3 w-3" />
              Duplicate
            </button>
          )}
          <button
            type="button"
            onClick={onRemove}
            className="cursor-pointer text-xs text-red-400 hover:text-red-300"
          >
            Remove
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {/* Duration Type */}
        <div>
          <label className="mb-1 block text-xs text-gray-500">Duration Type</label>
          <select
            value={segment.duration_type}
            onChange={(e) => updateField('duration_type', e.target.value as DurationType)}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          >
            {DURATION_TYPES.map((t) => (
              <option key={t.value} value={t.value}>{t.label}</option>
            ))}
          </select>
        </div>

        {/* Duration Value */}
        <div>
          <label className="mb-1 block text-xs text-gray-500">
            {segment.duration_type === 'time'
              ? 'Seconds'
              : segment.duration_type === 'distance'
                ? 'Meters'
                : 'Calories'}
          </label>
          <input
            type="number"
            min={1}
            value={segment.duration_value}
            onChange={(e) => updateField('duration_value', Math.max(1, parseInt(e.target.value) || 1))}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          />
        </div>

        {/* Intensity % */}
        <div>
          <label className="mb-1 block text-xs text-gray-500">
            Intensity % FTP{' '}
            {preview && <span className="text-gray-600">= {preview.pace}/500m / {preview.watts}</span>}
          </label>
          <input
            type="number"
            min={0}
            max={200}
            placeholder="e.g. 85 (leave blank for rest)"
            value={segment.target_intensity ?? ''}
            onChange={(e) => {
              const val = parseInt(e.target.value) || 0;
              updateField('target_intensity', val > 0 ? val : null);
            }}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          />
        </div>

        {/* Stroke Rate */}
        <div>
          <label className="mb-1 block text-xs text-gray-500">Stroke Rate (spm)</label>
          <input
            type="number"
            min={0}
            max={50}
            value={segment.target_stroke_rate ?? ''}
            onChange={(e) => {
              const val = parseInt(e.target.value) || 0;
              updateField('target_stroke_rate', val > 0 ? val : null);
            }}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          />
        </div>
      </div>
    </div>
  );
}
