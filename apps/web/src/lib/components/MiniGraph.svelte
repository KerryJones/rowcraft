<script lang="ts">
	import type { WorkoutSegment } from '$lib/types';

	interface Props {
		segments: WorkoutSegment[];
		height?: number;
	}

	let { segments, height = 48 }: Props = $props();

	const segmentColors: Record<string, string> = {
		work: '#3b82f6',
		rest: '#6b7280',
		warmup: '#22c55e',
		cooldown: '#eab308'
	};

	// svelte-ignore state_referenced_locally
	const maxBarHeight = height;
	// svelte-ignore state_referenced_locally
	const minBarHeight = Math.round(height * 0.25);

	const bars = $derived.by(() => {
		const paces = segments
			.filter((s) => s.target_split)
			.map((s) => s.target_split!.pace);

		const minPace = paces.length > 0 ? Math.min(...paces) : 1200;
		const maxPace = paces.length > 0 ? Math.max(...paces) : 1800;
		const paceRange = maxPace - minPace || 1;

		return segments.map((seg) => {
			let barHeight: number;
			if (seg.target_split) {
				const normalizedIntensity = 1 - (seg.target_split.pace - minPace) / paceRange;
				barHeight = minBarHeight + normalizedIntensity * (maxBarHeight - minBarHeight);
			} else if (seg.type === 'rest') {
				barHeight = minBarHeight;
			} else {
				barHeight = (minBarHeight + maxBarHeight) / 2;
			}

			let widthWeight = seg.duration_value;
			if (seg.duration_type === 'distance') {
				widthWeight = seg.duration_value / 5;
			}

			return {
				height: barHeight,
				widthWeight: widthWeight * (seg.repeat || 1),
				color: segmentColors[seg.type] ?? segmentColors.work
			};
		});
	});

	const totalWeight = $derived(bars.reduce((sum, b) => sum + b.widthWeight, 0) || 1);
</script>

<div class="flex items-end gap-px overflow-hidden" style="height: {height}px;">
	{#each bars as bar}
		<div
			style="flex: {bar.widthWeight / totalWeight}; height: {bar.height}px; background-color: {bar.color}; min-width: 3px;"
		></div>
	{/each}
</div>
