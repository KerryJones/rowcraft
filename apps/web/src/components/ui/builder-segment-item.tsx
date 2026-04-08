'use client';

import { ChevronUp, ChevronDown, Copy, Trash2 } from 'lucide-react';
import type { WorkoutSegment, DurationType } from '@/lib/types';
import { formatPace } from '@/lib/utils/format';
import { resolveIntensityToPace, getEffectiveFtp, intensityToHrZone } from '@/lib/utils/ftp';
import { getSegmentDisplayColor } from '@/lib/utils/segment-color';

export const SEGMENT_GRID_COLS = '2rem 4.5rem 1fr 1fr 3.5rem 5rem';

const DURATION_TYPE_OPTIONS: { value: DurationType; label: string }[] = [
	{ value: 'time', label: 'Time' },
	{ value: 'distance', label: 'Dist' },
	{ value: 'calories', label: 'Cal' },
];

interface BuilderSegmentItemProps {
	segment: WorkoutSegment;
	index: number;
	isFirst: boolean;
	isLast: boolean;
	onChange: (segment: WorkoutSegment) => void;
	onMoveUp: () => void;
	onMoveDown: () => void;
	onDuplicate: () => void;
	onRemove: () => void;
	ftpWatts: number | null;
}

export function BuilderSegmentItem({
	segment,
	index,
	isFirst,
	isLast,
	onChange,
	onMoveUp,
	onMoveDown,
	onDuplicate,
	onRemove,
	ftpWatts,
}: BuilderSegmentItemProps) {
	const color = getSegmentDisplayColor(segment);
	const ftp = getEffectiveFtp(ftpWatts);

	function updateField<K extends keyof WorkoutSegment>(key: K, value: WorkoutSegment[K]) {
		const updated = { ...segment, [key]: value };
		if (key === 'target_intensity') {
			updated.target_hr_zone = intensityToHrZone(updated.target_intensity);
		}
		onChange(updated);
	}

	const preview = segment.target_intensity
		? formatPace(resolveIntensityToPace(segment.target_intensity, ftp))
		: null;

	return (
		<div className="group flex min-h-[48px] overflow-hidden rounded-lg border border-gray-700/50 bg-gray-800/50">
			{/* Left color bar */}
			<div className="w-1 shrink-0" style={{ backgroundColor: color }} />

			{/* Editable fields — flex-wrap on mobile, CSS grid on sm+ */}
			<div
				className="flex flex-1 flex-wrap items-center gap-1.5 px-2.5 py-2 sm:grid sm:items-center"
				style={{ gridTemplateColumns: SEGMENT_GRID_COLS }}
			>
				{/* # */}
				<span className="w-5 shrink-0 text-center text-xs text-gray-600 sm:w-auto">
					{index + 1}
				</span>

				{/* Type */}
				<div className="flex flex-col gap-0.5">
					<span className="text-[10px] text-gray-500 sm:hidden">Type</span>
					<select
						value={segment.duration_type}
						onChange={(e) => updateField('duration_type', e.target.value as DurationType)}
						aria-label={`Segment ${index + 1} duration type`}
						className="rounded border border-gray-700 bg-gray-800/80 px-1.5 py-1 text-xs text-white focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500/50 sm:w-full"
					>
						{DURATION_TYPE_OPTIONS.map((t) => (
							<option key={t.value} value={t.value}>{t.label}</option>
						))}
					</select>
				</div>

				{/* Value */}
				<div className="flex flex-col gap-0.5">
					<span className="text-[10px] text-gray-500 sm:hidden">Value</span>
					<input
						type="number"
						min={1}
						value={segment.duration_value}
						onChange={(e) => updateField('duration_value', Math.max(1, parseInt(e.target.value, 10) || 1))}
						aria-label={`Segment ${index + 1} duration value`}
						className="w-16 rounded border border-gray-700 bg-gray-800/80 px-1.5 py-1 text-xs text-white focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500/50 sm:w-full"
					/>
				</div>

				{/* % FTP */}
				<div className="flex flex-col gap-0.5">
					<span className="text-[10px] text-gray-500 sm:hidden">% FTP</span>
					<input
						type="number"
						min={0}
						max={200}
						placeholder="—"
						value={segment.target_intensity ?? ''}
						onChange={(e) => {
							const val = parseInt(e.target.value, 10);
							updateField('target_intensity', !isNaN(val) && val > 0 ? val : null);
						}}
						aria-label={`Segment ${index + 1} intensity percent FTP`}
						className="w-16 rounded border border-gray-700 bg-gray-800/80 px-1.5 py-1 text-xs text-white placeholder-gray-600 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500/50 sm:w-full"
					/>
				</div>

				{/* SPM */}
				<div className="flex flex-col gap-0.5">
					<span className="text-[10px] text-gray-500 sm:hidden">SPM</span>
					<input
						type="number"
						min={0}
						max={50}
						placeholder="—"
						value={segment.target_stroke_rate ?? ''}
						onChange={(e) => {
							const val = parseInt(e.target.value, 10);
							updateField('target_stroke_rate', !isNaN(val) && val > 0 ? val : null);
						}}
						aria-label={`Segment ${index + 1} stroke rate`}
						className="w-12 rounded border border-gray-700 bg-gray-800/80 px-1.5 py-1 text-xs text-white placeholder-gray-600 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500/50 sm:w-full"
					/>
				</div>

				{/* Pace preview */}
				<div className="flex flex-col gap-0.5">
					<span className="text-[10px] text-gray-500 sm:hidden">Pace</span>
					<span className={preview ? 'text-[11px] text-gray-500' : 'text-[11px] text-gray-700'}>
						{preview ? `${preview}/500m` : '—'}
					</span>
				</div>
			</div>

			{/* Action buttons (hover/focus-reveal) */}
			{/* TODO: tabIndex={-1} on buttons means keyboard users can't reach them — remove tabIndex to fix */}
			<div className="flex shrink-0 items-center gap-0.5 pr-1 opacity-0 transition-opacity duration-150 group-hover:opacity-100 group-focus-within:opacity-100">
				<button
					type="button"
					tabIndex={-1}
					onClick={onDuplicate}
					title="Duplicate"
					aria-label={`Duplicate segment ${index + 1}`}
					className="flex h-8 w-8 cursor-pointer items-center justify-center rounded text-gray-500 transition-colors hover:bg-gray-700 hover:text-gray-300"
				>
					<Copy className="h-3.5 w-3.5" />
				</button>
				<button
					type="button"
					tabIndex={-1}
					onClick={onMoveUp}
					disabled={isFirst}
					title="Move up"
					aria-label={`Move segment ${index + 1} up`}
					className="flex h-8 w-8 cursor-pointer items-center justify-center rounded text-gray-500 transition-colors hover:bg-gray-700 hover:text-gray-300 disabled:cursor-not-allowed disabled:opacity-30"
				>
					<ChevronUp className="h-3.5 w-3.5" />
				</button>
				<button
					type="button"
					tabIndex={-1}
					onClick={onMoveDown}
					disabled={isLast}
					title="Move down"
					aria-label={`Move segment ${index + 1} down`}
					className="flex h-8 w-8 cursor-pointer items-center justify-center rounded text-gray-500 transition-colors hover:bg-gray-700 hover:text-gray-300 disabled:cursor-not-allowed disabled:opacity-30"
				>
					<ChevronDown className="h-3.5 w-3.5" />
				</button>
				<button
					type="button"
					tabIndex={-1}
					onClick={onRemove}
					title="Remove"
					aria-label={`Remove segment ${index + 1}`}
					className="flex h-8 w-8 cursor-pointer items-center justify-center rounded text-red-500 transition-colors hover:bg-gray-700 hover:text-red-400"
				>
					<Trash2 className="h-3.5 w-3.5" />
				</button>
			</div>
		</div>
	);
}
