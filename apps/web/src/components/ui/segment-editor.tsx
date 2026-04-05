'use client';

import type { WorkoutSegment, SegmentType, DurationType } from '@/lib/types';
import { formatPace } from '@/lib/utils/format';
import { resolveIntensityToPace, getEffectiveFtp, formatWatts, intensityToWatts, HR_ZONES } from '@/lib/utils/ftp';

const SEGMENT_TYPES: { value: SegmentType; label: string }[] = [
  { value: 'work', label: 'Work' },
  { value: 'rest', label: 'Rest' },
  { value: 'warmup', label: 'Warm Up' },
  { value: 'cooldown', label: 'Cool Down' },
];

const DURATION_TYPES: { value: DurationType; label: string }[] = [
  { value: 'time', label: 'Time (seconds)' },
  { value: 'distance', label: 'Distance (meters)' },
  { value: 'calories', label: 'Calories' },
];

interface SegmentEditorProps {
  segment: WorkoutSegment;
  onChange: (segment: WorkoutSegment) => void;
  onRemove: () => void;
  ftpWatts?: number | null;
}

export function SegmentEditor({ segment, onChange, onRemove, ftpWatts }: SegmentEditorProps) {
  const ftp = getEffectiveFtp(ftpWatts ?? null);

  function updateField<K extends keyof WorkoutSegment>(key: K, value: WorkoutSegment[K]) {
    onChange({ ...segment, [key]: value });
  }

  // Resolve current intensity to pace/watts for preview
  const preview = segment.target_intensity
    ? (() => {
        const { paceMid } = resolveIntensityToPace(segment.target_intensity, ftp);
        const midPct = Math.round((segment.target_intensity.min + segment.target_intensity.max) / 2);
        return { pace: formatPace(paceMid), watts: formatWatts(intensityToWatts(midPct, ftp)) };
      })()
    : null;

  return (
    <div className="space-y-3 rounded-lg border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between">
        <h4 className="text-sm font-medium text-white">Edit Segment</h4>
        <button
          type="button"
          onClick={onRemove}
          className="cursor-pointer text-xs text-red-400 hover:text-red-300"
        >
          Remove
        </button>
      </div>

      <div className="grid grid-cols-2 gap-3">
        {/* Segment Type */}
        <div>
          <label className="mb-1 block text-xs text-gray-500">Type</label>
          <select
            value={segment.type}
            onChange={(e) => updateField('type', e.target.value as SegmentType)}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          >
            {SEGMENT_TYPES.map((t) => (
              <option key={t.value} value={t.value}>{t.label}</option>
            ))}
          </select>
        </div>

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

        {/* Intensity % (min) */}
        <div>
          <label className="mb-1 block text-xs text-gray-500">
            Intensity % min{' '}
            {preview && <span className="text-gray-600">= {preview.pace}/500m / {preview.watts}</span>}
          </label>
          <input
            type="number"
            min={0}
            max={200}
            placeholder="e.g. 85"
            value={segment.target_intensity?.min ?? ''}
            onChange={(e) => {
              const min = parseInt(e.target.value) || 0;
              const max = segment.target_intensity?.max ?? Math.min(200, min + 10);
              updateField('target_intensity', min > 0 ? { min, max: Math.max(min, max) } : null);
            }}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          />
        </div>

        {/* Intensity % (max) */}
        <div>
          <label className="mb-1 block text-xs text-gray-500">Intensity % max</label>
          <input
            type="number"
            min={0}
            max={200}
            placeholder="e.g. 95"
            value={segment.target_intensity?.max ?? ''}
            onChange={(e) => {
              const max = parseInt(e.target.value) || 0;
              const min = segment.target_intensity?.min ?? Math.max(0, max - 10);
              updateField('target_intensity', max > 0 ? { min: Math.min(min, max), max } : null);
            }}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          />
        </div>

        {/* Stroke Rate */}
        <div>
          <label className="mb-1 block text-xs text-gray-500">Stroke Rate (min)</label>
          <input
            type="number"
            min={0}
            max={60}
            value={segment.target_stroke_rate?.min ?? ''}
            onChange={(e) => {
              const min = parseInt(e.target.value) || 0;
              const max = segment.target_stroke_rate?.max ?? min + 4;
              updateField('target_stroke_rate', min > 0 ? { min, max } : null);
            }}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          />
        </div>

        <div>
          <label className="mb-1 block text-xs text-gray-500">Stroke Rate (max)</label>
          <input
            type="number"
            min={0}
            max={60}
            value={segment.target_stroke_rate?.max ?? ''}
            onChange={(e) => {
              const max = parseInt(e.target.value) || 0;
              const min = segment.target_stroke_rate?.min ?? Math.max(0, max - 4);
              updateField('target_stroke_rate', max > 0 ? { min, max } : null);
            }}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          />
        </div>

        {/* HR Zone */}
        <div>
          <label className="mb-1 block text-xs text-gray-500">HR Zone</label>
          <select
            value={segment.target_hr_zone ?? ''}
            onChange={(e) =>
              updateField('target_hr_zone', e.target.value ? parseInt(e.target.value) : null)
            }
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
          >
            <option value="">None</option>
            {HR_ZONES.map((zone, i) => (
              <option key={zone.name} value={i + 1}>Z{i + 1} {zone.label}</option>
            ))}
          </select>
        </div>
      </div>
    </div>
  );
}
