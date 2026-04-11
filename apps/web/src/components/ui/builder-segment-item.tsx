'use client';

import { ChevronUp, ChevronDown, Copy, Trash2 } from 'lucide-react';
import type { WorkoutSegment, DurationType } from '@/lib/types';
import { formatPace } from '@/lib/utils/format';
import { resolveIntensityToPace, getEffectiveFtp, intensityToHrZone } from '@/lib/utils/ftp';
import { getSegmentDisplayColor } from '@/lib/utils/segment-color';
import { Switch } from '@/components/ui/switch';

export const SEGMENT_GRID_COLS = '2rem 2.5rem 4.5rem 8rem 9rem 3.5rem';

const DURATION_UNIT_LABELS: Record<DurationType, string> = {
	time: 's',
	distance: 'm',
	calories: 'cal',
};

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

	function toggleRest(checked: boolean) {
		onChange({
			...segment,
			is_rest: checked,
			...(checked && {
				duration_type: 'time',
				target_intensity: null,
				target_stroke_rate: null,
				target_hr_zone: null,
			}),
		});
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
				className="flex flex-1 flex-wrap items-center gap-3 px-2.5 py-2 sm:grid sm:items-center"
				style={{ gridTemplateColumns: SEGMENT_GRID_COLS }}
			>
				{/* # */}
				<span className="w-5 shrink-0 text-center text-xs text-gray-600 sm:w-auto">
					{index + 1}
				</span>

				{/* Rest toggle */}
				<div className="flex items-center justify-center">
					<Switch
						size="sm"
						checked={!!segment.is_rest}
						onCheckedChange={toggleRest}
						aria-label={`Toggle rest for segment ${index + 1}`}
					/>
				</div>

				{/* Type */}
				<div className="flex flex-col gap-0.5">
					<span className="text-[10px] text-gray-500 sm:hidden">Type</span>
					{segment.is_rest ? (
						<span className="rounded border border-gray-700/50 bg-gray-800/40 px-1.5 py-1 text-xs text-gray-500">
							Time
						</span>
					) : (
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
					)}
				</div>

				{/* Value + unit suffix */}
				<div className="flex flex-col gap-0.5">
					<span className="text-[10px] text-gray-500 sm:hidden">Value</span>
					<div className="relative">
						<input
							type="number"
							min={1}
							value={segment.duration_value}
							onChange={(e) => updateField('duration_value', Math.max(1, parseInt(e.target.value, 10) || 1))}
							aria-label={`Segment ${index + 1} duration value`}
							className="w-full rounded border border-gray-700 bg-gray-800/80 py-1 pl-1.5 pr-7 text-xs text-white focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500/50"
						/>
						<span className="pointer-events-none absolute right-1.5 top-1/2 -translate-y-1/2 text-[11px] text-gray-500">
							{DURATION_UNIT_LABELS[segment.duration_type]}
						</span>
					</div>
				</div>

				{/* % FTP + inline pace */}
				<div className="flex flex-col gap-0.5">
					<span className="text-[10px] text-gray-500 sm:hidden">% FTP</span>
					{segment.is_rest ? (
						<span className="py-1 text-xs text-gray-700">—</span>
					) : (
						<div className="flex items-center gap-1.5">
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
								className="w-14 rounded border border-gray-700 bg-gray-800/80 px-1.5 py-1 text-xs text-white placeholder-gray-600 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500/50"
							/>
							<span className={`whitespace-nowrap text-[11px] ${preview ? 'text-gray-500' : 'text-gray-700'}`}>
								{preview ? `${preview}/500m` : '—'}
							</span>
						</div>
					)}
				</div>

				{/* SPM */}
				<div className="flex flex-col gap-0.5">
					<span className="text-[10px] text-gray-500 sm:hidden">SPM</span>
					{segment.is_rest ? (
						<span className="py-1 text-xs text-gray-700">—</span>
					) : (
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
							className="w-full rounded border border-gray-700 bg-gray-800/80 px-1.5 py-1 text-xs text-white placeholder-gray-600 focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500/50"
						/>
					)}
				</div>
			</div>

			{/* Action buttons (hover/focus-reveal) */}
			<div className="flex shrink-0 items-center gap-0.5 pr-1 opacity-0 transition-opacity duration-150 group-hover:opacity-100 group-focus-within:opacity-100">
				<button
					type="button"
					onClick={onDuplicate}
					title="Duplicate"
					aria-label={`Duplicate segment ${index + 1}`}
					className="flex h-8 w-8 cursor-pointer items-center justify-center rounded text-gray-500 transition-colors hover:bg-gray-700 hover:text-gray-300"
				>
					<Copy className="h-3.5 w-3.5" />
				</button>
				<button
					type="button"
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
