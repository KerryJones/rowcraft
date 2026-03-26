<script lang="ts">
	import type { WorkoutSegment, SegmentType, DurationType } from '$lib/types';

	interface Props {
		segment: WorkoutSegment;
		index: number;
		total: number;
		onUpdate: (segment: WorkoutSegment) => void;
		onDelete: () => void;
		onMoveUp: () => void;
		onMoveDown: () => void;
		error: string | null;
	}

	let { segment, index, total, onUpdate, onDelete, onMoveUp, onMoveDown, error }: Props = $props();

	const borderColors: Record<string, string> = {
		work: 'border-l-blue-500',
		rest: 'border-l-gray-500',
		warmup: 'border-l-emerald-500',
		cooldown: 'border-l-yellow-500'
	};

	const segmentTypes: { value: SegmentType; label: string }[] = [
		{ value: 'work', label: 'Work' },
		{ value: 'rest', label: 'Rest' },
		{ value: 'warmup', label: 'Warm Up' },
		{ value: 'cooldown', label: 'Cool Down' }
	];

	const durationTypes: { value: DurationType; label: string }[] = [
		{ value: 'time', label: 'Time (sec)' },
		{ value: 'distance', label: 'Distance (m)' },
		{ value: 'calories', label: 'Calories' }
	];

	// Split target local state
	let hasSplitTarget = $state(!!segment.target_split);
	let splitMin = $state(segment.target_split?.min ?? 1200);
	let splitMax = $state(segment.target_split?.max ?? 1200);
	let hasStrokeTarget = $state(!!segment.target_stroke_rate);
	let spmMin = $state(segment.target_stroke_rate?.min ?? 24);
	let spmMax = $state(segment.target_stroke_rate?.max ?? 28);

	function updateField(field: string, value: any) {
		const updated = { ...segment, [field]: value };

		// Sync targets
		if (hasSplitTarget) {
			updated.target_split = { min: splitMin, max: splitMax };
		} else {
			updated.target_split = null;
		}

		if (hasStrokeTarget) {
			updated.target_stroke_rate = { min: spmMin, max: spmMax };
		} else {
			updated.target_stroke_rate = null;
		}

		onUpdate(updated);
	}

	function syncTargets() {
		const updated = { ...segment };
		updated.target_split = hasSplitTarget ? { min: splitMin, max: splitMax } : null;
		updated.target_stroke_rate = hasStrokeTarget ? { min: spmMin, max: spmMax } : null;
		onUpdate(updated);
	}

	function paceToString(tenths: number): string {
		const totalSeconds = Math.floor(tenths / 10);
		const minutes = Math.floor(totalSeconds / 60);
		const seconds = totalSeconds % 60;
		const t = tenths % 10;
		return `${minutes}:${seconds.toString().padStart(2, '0')}.${t}`;
	}

	function parsePaceInput(value: string): number | null {
		const match = value.match(/^(\d+):(\d{1,2})(?:\.(\d))?$/);
		if (!match) return null;
		const [, mins, secs, tenths] = match;
		const s = parseInt(secs);
		if (s >= 60) return null;
		return parseInt(mins) * 600 + s * 10 + (tenths ? parseInt(tenths) : 0);
	}

	function handlePaceMinChange(e: Event) {
		const val = parsePaceInput((e.target as HTMLInputElement).value);
		if (val !== null) {
			splitMin = val;
			syncTargets();
		}
	}

	function handlePaceMaxChange(e: Event) {
		const val = parsePaceInput((e.target as HTMLInputElement).value);
		if (val !== null) {
			splitMax = val;
			syncTargets();
		}
	}
</script>

<div class="rounded-lg border border-gray-800 bg-gray-900 border-l-4 {borderColors[segment.type] ?? 'border-l-gray-500'}">
	<!-- Header -->
	<div class="flex items-center justify-between border-b border-gray-800 px-4 py-2">
		<div class="flex items-center gap-3">
			<span class="text-xs font-medium text-gray-500">{index + 1}</span>
			<select
				value={segment.type}
				onchange={(e) => updateField('type', (e.target as HTMLSelectElement).value)}
				class="rounded border border-gray-700 bg-gray-800 px-2 py-1 text-sm text-white"
			>
				{#each segmentTypes as st}
					<option value={st.value}>{st.label}</option>
				{/each}
			</select>
		</div>
		<div class="flex items-center gap-1">
			<button
				onclick={onMoveUp}
				disabled={index === 0}
				class="rounded p-1 text-gray-500 hover:bg-gray-800 hover:text-white disabled:opacity-30"
				aria-label="Move up"
			>
				<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
				</svg>
			</button>
			<button
				onclick={onMoveDown}
				disabled={index === total - 1}
				class="rounded p-1 text-gray-500 hover:bg-gray-800 hover:text-white disabled:opacity-30"
				aria-label="Move down"
			>
				<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
				</svg>
			</button>
			<button
				onclick={onDelete}
				class="rounded p-1 text-gray-500 hover:bg-red-500/10 hover:text-red-400"
				aria-label="Delete segment"
			>
				<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
				</svg>
			</button>
		</div>
	</div>

	<!-- Body -->
	<div class="space-y-3 px-4 py-3">
		<!-- Duration -->
		<div class="flex items-center gap-3">
			<select
				value={segment.duration_type}
				onchange={(e) => updateField('duration_type', (e.target as HTMLSelectElement).value)}
				class="rounded border border-gray-700 bg-gray-800 px-2 py-1.5 text-sm text-white"
			>
				{#each durationTypes as dt}
					<option value={dt.value}>{dt.label}</option>
				{/each}
			</select>
			<input
				type="number"
				value={segment.duration_value}
				onchange={(e) => updateField('duration_value', parseInt((e.target as HTMLInputElement).value) || 0)}
				min="1"
				class="w-24 rounded border border-gray-700 bg-gray-800 px-3 py-1.5 text-sm text-white"
			/>
			<div class="flex items-center gap-2">
				<label class="text-xs text-gray-500">Repeat</label>
				<input
					type="number"
					value={segment.repeat}
					onchange={(e) => updateField('repeat', Math.max(1, parseInt((e.target as HTMLInputElement).value) || 1))}
					min="1"
					class="w-16 rounded border border-gray-700 bg-gray-800 px-2 py-1.5 text-sm text-white"
				/>
			</div>
		</div>

		<!-- Split target -->
		<div>
			<label class="flex items-center gap-2 text-sm text-gray-400">
				<input
					type="checkbox"
					bind:checked={hasSplitTarget}
					onchange={syncTargets}
					class="h-3.5 w-3.5 rounded border-gray-600 bg-gray-800"
				/>
				Target pace
			</label>
			{#if hasSplitTarget}
				<div class="mt-2 flex items-center gap-2">
					<input
						type="text"
						value={paceToString(splitMin)}
						onchange={handlePaceMinChange}
						placeholder="2:00.0"
						class="w-24 rounded border border-gray-700 bg-gray-800 px-3 py-1.5 text-sm text-white"
					/>
					<span class="text-xs text-gray-500">to</span>
					<input
						type="text"
						value={paceToString(splitMax)}
						onchange={handlePaceMaxChange}
						placeholder="2:05.0"
						class="w-24 rounded border border-gray-700 bg-gray-800 px-3 py-1.5 text-sm text-white"
					/>
					<span class="text-xs text-gray-500">/500m</span>
				</div>
			{/if}
		</div>

		<!-- Stroke rate target -->
		<div>
			<label class="flex items-center gap-2 text-sm text-gray-400">
				<input
					type="checkbox"
					bind:checked={hasStrokeTarget}
					onchange={syncTargets}
					class="h-3.5 w-3.5 rounded border-gray-600 bg-gray-800"
				/>
				Target stroke rate
			</label>
			{#if hasStrokeTarget}
				<div class="mt-2 flex items-center gap-2">
					<input
						type="number"
						bind:value={spmMin}
						onchange={syncTargets}
						min="10"
						max="50"
						class="w-20 rounded border border-gray-700 bg-gray-800 px-3 py-1.5 text-sm text-white"
					/>
					<span class="text-xs text-gray-500">to</span>
					<input
						type="number"
						bind:value={spmMax}
						onchange={syncTargets}
						min="10"
						max="50"
						class="w-20 rounded border border-gray-700 bg-gray-800 px-3 py-1.5 text-sm text-white"
					/>
					<span class="text-xs text-gray-500">spm</span>
				</div>
			{/if}
		</div>

		{#if error}
			<p class="text-sm text-red-400">{error}</p>
		{/if}
	</div>
</div>
