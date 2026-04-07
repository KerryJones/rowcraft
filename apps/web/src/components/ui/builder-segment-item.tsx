'use client';

import { ChevronUp, ChevronDown, Copy } from 'lucide-react';
import type { WorkoutSegment } from '@/lib/types';
import { isRestSegment } from '@/lib/types';
import { formatSegmentDuration } from '@/lib/utils/format';
import { getSegmentDisplayColor } from '@/lib/utils/segment-color';

interface BuilderSegmentItemProps {
  segment: WorkoutSegment;
  index: number;
  isSelected: boolean;
  isFirst: boolean;
  isLast: boolean;
  onSelect: () => void;
  onMoveUp: () => void;
  onMoveDown: () => void;
  onDuplicate: () => void;
}

export function BuilderSegmentItem({
  segment,
  index,
  isSelected,
  isFirst,
  isLast,
  onSelect,
  onMoveUp,
  onMoveDown,
  onDuplicate,
}: BuilderSegmentItemProps) {
  const color = getSegmentDisplayColor(segment);
  const isRest = isRestSegment(segment);
  const label = isRest ? 'Rest' : segment.target_hr_zone != null ? `Z${segment.target_hr_zone}` : 'Active';

  return (
    <div
      className={`group flex min-h-[48px] overflow-hidden rounded-lg border border-gray-700/50 bg-gray-800/50 transition-all duration-150 ${
        isSelected ? 'ring-2 ring-blue-500' : 'ring-0'
      }`}
    >
      {/* Colored left bar */}
      <div className="w-1 shrink-0" style={{ backgroundColor: color }} />

      {/* Main clickable area */}
      <button
        type="button"
        onClick={onSelect}
        className="flex flex-1 cursor-pointer items-center gap-3 px-3 py-2.5 text-left"
      >
        {/* Index */}
        <span className="w-5 shrink-0 text-center text-xs text-gray-600">
          {index + 1}
        </span>

        {/* Zone/rest badge */}
        <span
          className="shrink-0 rounded px-1.5 py-0.5 text-xs font-medium"
          style={{ backgroundColor: color + '33', color }}
        >
          {label}
        </span>

        {/* Duration */}
        <span className="text-sm font-medium text-white">
          {formatSegmentDuration(segment)}
        </span>

        {/* Intensity */}
        {segment.target_intensity != null && (
          <span className="text-xs text-gray-500">
            {segment.target_intensity}% FTP
          </span>
        )}

        {/* Stroke rate badge */}
        {segment.target_stroke_rate != null && (
          <span className="rounded bg-gray-700/50 px-1.5 py-0.5 text-xs text-gray-400">
            {segment.target_stroke_rate} spm
          </span>
        )}
      </button>

      {/* Action buttons */}
      <div className="flex shrink-0 items-center gap-0.5 pr-1 opacity-0 transition-opacity duration-150 group-hover:opacity-100 group-focus-within:opacity-100">
        <button
          type="button"
          tabIndex={-1}
          onClick={(e) => { e.stopPropagation(); onDuplicate(); }}
          title="Duplicate"
          className="flex h-8 w-8 cursor-pointer items-center justify-center rounded text-gray-500 transition-colors hover:bg-gray-700 hover:text-gray-300"
        >
          <Copy className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          tabIndex={-1}
          onClick={(e) => { e.stopPropagation(); onMoveUp(); }}
          title="Move up"
          disabled={isFirst}
          className="flex h-8 w-8 cursor-pointer items-center justify-center rounded text-gray-500 transition-colors hover:bg-gray-700 hover:text-gray-300 disabled:cursor-not-allowed disabled:opacity-30"
        >
          <ChevronUp className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          tabIndex={-1}
          onClick={(e) => { e.stopPropagation(); onMoveDown(); }}
          title="Move down"
          disabled={isLast}
          className="flex h-8 w-8 cursor-pointer items-center justify-center rounded text-gray-500 transition-colors hover:bg-gray-700 hover:text-gray-300 disabled:cursor-not-allowed disabled:opacity-30"
        >
          <ChevronDown className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}
