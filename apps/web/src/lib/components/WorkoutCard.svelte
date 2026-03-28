<script lang="ts">
	import type { Workout } from '$lib/types';
	import { formatWorkoutType, formatDuration, formatDistance } from '$lib/utils/format';
	import { computeTotalTime, computeTotalDistance, computeSegmentCount } from '$lib/utils/workout';
	import MiniGraph from './MiniGraph.svelte';

	interface Props {
		workout: Workout;
		onclick: () => void;
	}

	let { workout, onclick }: Props = $props();

	const typeBadgeColors: Record<string, string> = {
		intervals: 'bg-blue-500/10 text-blue-400',
		single_distance: 'bg-emerald-500/10 text-emerald-400',
		single_time: 'bg-purple-500/10 text-purple-400',
		variable_intervals: 'bg-amber-500/10 text-amber-400'
	};

	const badgeClass = $derived(typeBadgeColors[workout.workout_type] ?? 'bg-gray-500/10 text-gray-400');

	const totalTime = $derived(computeTotalTime(workout.segments ?? []));
	const totalDistance = $derived(computeTotalDistance(workout.segments ?? []));
	const segmentCount = $derived(computeSegmentCount(workout.segments ?? []));

	const summaryLabel = $derived.by(() => {
		const parts: string[] = [];
		if (totalTime) parts.push(formatDuration(totalTime));
		if (totalDistance) parts.push(formatDistance(totalDistance));
		parts.push(`${segmentCount} seg`);
		return parts.join(' · ');
	});
</script>

<button
	{onclick}
	class="group w-full overflow-hidden rounded-xl border border-gray-800 bg-gray-900 text-left transition-colors hover:border-gray-700 hover:bg-gray-800/50"
>
	<!-- Mini workout graph -->
	{#if workout.segments?.length > 0}
		<div class="opacity-80 group-hover:opacity-100 transition-opacity">
			<MiniGraph segments={workout.segments} height={48} />
		</div>
	{:else}
		<div class="h-12 bg-gray-800/30"></div>
	{/if}

	<div class="p-4">
		<!-- Title + badge -->
		<div class="mb-2 flex items-start justify-between gap-2">
			<h3 class="font-semibold text-white group-hover:text-blue-400 transition-colors">
				{workout.title}
			</h3>
			<span class="shrink-0 rounded-full px-2.5 py-0.5 text-xs font-medium {badgeClass}">
				{formatWorkoutType(workout.workout_type)}
			</span>
		</div>

		<!-- Stats summary -->
		<p class="mb-3 text-xs font-mono text-gray-500">{summaryLabel}</p>

		<!-- Tags -->
		{#if workout.tags?.length > 0}
			<div class="mb-2 flex flex-wrap gap-1.5">
				{#each workout.tags.slice(0, 3) as tag}
					<span class="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-400">{tag}</span>
				{/each}
				{#if workout.tags.length > 3}
					<span class="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-500">
						+{workout.tags.length - 3}
					</span>
				{/if}
			</div>
		{/if}

		{#if workout.fork_count > 0}
			<div class="text-xs text-gray-500 flex items-center gap-1">
				<svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
				</svg>
				{workout.fork_count}
			</div>
		{/if}
	</div>
</button>
