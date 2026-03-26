<script lang="ts">
	import type { WorkoutSegment } from '$lib/types';
	import { formatDuration, formatDistance, formatPace, formatSegmentType } from '$lib/utils/format';

	interface Props {
		segments: WorkoutSegment[];
	}

	let { segments }: Props = $props();

	const segmentColors: Record<string, string> = {
		work: '#3b82f6',
		rest: '#6b7280',
		warmup: '#22c55e',
		cooldown: '#eab308'
	};

	const maxHeight = 120;
	const minHeight = 30;

	// Calculate bar heights based on intensity (target split pace)
	// Lower pace = higher intensity = taller bar
	const bars = $derived(() => {
		const paces = segments
			.filter((s) => s.target_split)
			.map((s) => s.target_split!.min);

		const minPace = paces.length > 0 ? Math.min(...paces) : 1200;
		const maxPace = paces.length > 0 ? Math.max(...paces) : 1800;
		const paceRange = maxPace - minPace || 1;

		return segments.map((seg) => {
			let height: number;
			if (seg.target_split) {
				// Faster pace (lower number) = taller bar
				const normalizedIntensity = 1 - (seg.target_split.min - minPace) / paceRange;
				height = minHeight + normalizedIntensity * (maxHeight - minHeight);
			} else if (seg.type === 'rest') {
				height = minHeight;
			} else {
				height = (minHeight + maxHeight) / 2;
			}

			// Calculate relative width based on duration
			let widthWeight = seg.duration_value;
			if (seg.duration_type === 'distance') {
				widthWeight = seg.duration_value / 5; // rough: 5m ~= 1s
			}

			return {
				segment: seg,
				height,
				widthWeight: widthWeight * (seg.repeat || 1),
				color: segmentColors[seg.type] ?? segmentColors.work
			};
		});
	});

	const totalWeight = $derived(bars().reduce((sum, b) => sum + b.widthWeight, 0) || 1);

	function durationLabel(seg: WorkoutSegment): string {
		switch (seg.duration_type) {
			case 'time':
				return formatDuration(seg.duration_value);
			case 'distance':
				return formatDistance(seg.duration_value);
			case 'calories':
				return `${seg.duration_value}cal`;
			default:
				return '';
		}
	}
</script>

<div class="flex items-end gap-1" style="height: {maxHeight + 40}px;">
	{#each bars() as bar}
		<div
			class="group relative flex flex-col items-center justify-end"
			style="flex: {bar.widthWeight / totalWeight}; min-width: 24px;"
		>
			<!-- Label on hover -->
			<div class="pointer-events-none absolute bottom-full mb-2 hidden rounded bg-gray-800 px-2 py-1 text-xs text-white shadow-lg group-hover:block whitespace-nowrap z-10">
				<p class="font-medium">{formatSegmentType(bar.segment.type)}</p>
				<p>{durationLabel(bar.segment)}</p>
				{#if bar.segment.target_split}
					<p>{formatPace(bar.segment.target_split.min)}/500m</p>
				{/if}
				{#if bar.segment.repeat > 1}
					<p>x{bar.segment.repeat}</p>
				{/if}
			</div>

			<!-- Bar -->
			<div
				class="w-full rounded-t transition-all duration-200 group-hover:opacity-80"
				style="height: {bar.height}px; background-color: {bar.color};"
			></div>

			<!-- Duration label below -->
			<p class="mt-1 truncate text-center text-[10px] text-gray-500 w-full">
				{durationLabel(bar.segment)}
			</p>
		</div>
	{/each}
</div>
