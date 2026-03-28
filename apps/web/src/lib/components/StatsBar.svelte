<script lang="ts">
	import type { WorkoutSegment } from '$lib/types';
	import { formatDuration, formatDistance } from '$lib/utils/format';
	import { computeTotalTime, computeTotalDistance, computeSegmentCount } from '$lib/utils/workout';

	interface Props {
		segments: WorkoutSegment[];
	}

	let { segments }: Props = $props();

	const totalTime = $derived(computeTotalTime(segments));
	const totalDistance = $derived(computeTotalDistance(segments));
	const segmentCount = $derived(computeSegmentCount(segments));
</script>

<div class="flex items-center gap-8 rounded-xl border border-gray-800 bg-gray-900 px-6 py-4">
	{#if totalTime}
		<div>
			<p class="text-xs text-gray-500 uppercase tracking-wider">Time</p>
			<p class="font-mono text-lg font-bold text-white">{formatDuration(totalTime)}</p>
		</div>
	{/if}
	{#if totalDistance}
		<div>
			<p class="text-xs text-gray-500 uppercase tracking-wider">Distance</p>
			<p class="font-mono text-lg font-bold text-white">{formatDistance(totalDistance)}</p>
		</div>
	{/if}
	<div>
		<p class="text-xs text-gray-500 uppercase tracking-wider">Segments</p>
		<p class="font-mono text-lg font-bold text-white">{segmentCount}</p>
	</div>
</div>
