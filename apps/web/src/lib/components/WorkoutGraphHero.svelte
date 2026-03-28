<script lang="ts">
	import type { WorkoutSegment } from '$lib/types';
	import { formatSegmentDuration, formatSegmentType } from '$lib/utils/format';

	interface Props {
		segments: WorkoutSegment[];
		selectedIndex?: number | null;
		onSelectSegment?: ((index: number) => void) | null;
	}

	let { segments, selectedIndex = null, onSelectSegment = null }: Props = $props();

	const segmentColors: Record<string, string> = {
		work: '#3b82f6',
		rest: '#6b7280',
		warmup: '#22c55e',
		cooldown: '#eab308'
	};

	const selectedColors: Record<string, string> = {
		work: '#60a5fa',
		rest: '#9ca3af',
		warmup: '#4ade80',
		cooldown: '#facc15'
	};

	const typeAbbrev: Record<string, string> = {
		work: 'W',
		rest: 'R',
		warmup: 'WU',
		cooldown: 'CD'
	};

	const maxHeight = 160;
	const minHeight = 40;

	const bars = $derived.by(() => {
		const paces = segments
			.filter((s) => s.target_split)
			.map((s) => s.target_split!.pace);

		const minPace = paces.length > 0 ? Math.min(...paces) : 1200;
		const maxPace = paces.length > 0 ? Math.max(...paces) : 1800;
		const paceRange = maxPace - minPace || 1;

		return segments.map((seg, i) => {
			let height: number;
			if (seg.target_split) {
				const normalizedIntensity = 1 - (seg.target_split.pace - minPace) / paceRange;
				height = minHeight + normalizedIntensity * (maxHeight - minHeight);
			} else if (seg.type === 'rest') {
				height = minHeight;
			} else {
				height = (minHeight + maxHeight) / 2;
			}

			let widthWeight = seg.duration_value;
			if (seg.duration_type === 'distance') {
				widthWeight = seg.duration_value / 5;
			}

			const isSelected = selectedIndex === i;

			return {
				segment: seg,
				index: i,
				height,
				widthWeight: widthWeight * (seg.repeat || 1),
				color: isSelected
					? (selectedColors[seg.type] ?? selectedColors.work)
					: (segmentColors[seg.type] ?? segmentColors.work),
				isSelected
			};
		});
	});

	const totalWeight = $derived(bars.reduce((sum, b) => sum + b.widthWeight, 0) || 1);
</script>

<div class="rounded-xl border border-gray-800 bg-gray-900 p-4">
	{#if segments.length === 0}
		<div class="flex h-48 items-center justify-center text-sm text-gray-600">
			Add segments below to build your workout
		</div>
	{:else}
		<div class="flex items-end gap-1" style="height: {maxHeight + 32}px;">
			{#each bars as bar}
				<button
					type="button"
					class="group relative flex flex-col items-center justify-end transition-all duration-200 {bar.isSelected ? 'ring-2 ring-blue-400 rounded-t' : ''}"
					style="flex: {bar.widthWeight / totalWeight}; min-width: 28px;"
					onclick={() => onSelectSegment?.(bar.index)}
					disabled={!onSelectSegment}
				>
					<!-- Bar -->
					<div
						class="w-full rounded-t transition-all duration-200 {onSelectSegment ? 'cursor-pointer hover:opacity-80' : ''}"
						style="height: {bar.height}px; background-color: {bar.color};"
					></div>

					<!-- Label below bar -->
					<div class="mt-1 w-full text-center">
						<p class="text-[10px] font-medium {bar.isSelected ? 'text-white' : 'text-gray-500'}">
							{typeAbbrev[bar.segment.type] ?? 'W'}
						</p>
						<p class="truncate text-[9px] text-gray-600">
							{formatSegmentDuration(bar.segment)}
						</p>
					</div>
				</button>
			{/each}
		</div>
	{/if}
</div>
