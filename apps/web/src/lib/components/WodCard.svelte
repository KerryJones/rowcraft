<script lang="ts">
	import type { Workout } from '$lib/types';
	import { formatWorkoutType } from '$lib/utils/format';
	import { computeTotalTime, computeTotalDistance, computeSegmentCount } from '$lib/utils/workout';
	import { formatDuration, formatDistance } from '$lib/utils/format';
	import MiniGraph from './MiniGraph.svelte';

	interface Props {
		workout: Workout;
		onShuffle: () => void;
		onView: () => void;
	}

	let { workout, onShuffle, onView }: Props = $props();

	const totalTime = $derived(computeTotalTime(workout.segments ?? []));
	const totalDistance = $derived(computeTotalDistance(workout.segments ?? []));
	const segmentCount = $derived(computeSegmentCount(workout.segments ?? []));
</script>

<div class="rounded-xl border border-blue-500/20 bg-gradient-to-r from-blue-500/5 to-gray-900 overflow-hidden">
	<!-- Header -->
	<div class="flex items-center justify-between px-5 pt-4 pb-2">
		<div class="flex items-center gap-2">
			<span class="rounded bg-blue-600 px-2 py-0.5 text-xs font-bold text-white tracking-wider">WOD</span>
			<span class="text-xs text-gray-500">Workout of the Day</span>
		</div>
		<button
			onclick={onShuffle}
			class="flex items-center gap-1.5 rounded-lg border border-gray-700 px-3 py-1.5 text-xs text-gray-400 transition-colors hover:border-gray-600 hover:text-white"
		>
			<svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
			</svg>
			Shuffle
		</button>
	</div>

	<!-- Mini graph -->
	{#if workout.segments?.length > 0}
		<div class="px-5">
			<MiniGraph segments={workout.segments} height={64} />
		</div>
	{/if}

	<!-- Content -->
	<div class="px-5 py-4">
		<div class="flex items-start justify-between gap-4">
			<div>
				<h3 class="text-lg font-semibold text-white">{workout.title}</h3>
				<div class="mt-1 flex items-center gap-3 text-xs text-gray-500 font-mono">
					{#if totalTime}
						<span>{formatDuration(totalTime)}</span>
					{/if}
					{#if totalDistance}
						<span>{formatDistance(totalDistance)}</span>
					{/if}
					<span>{segmentCount} seg</span>
					<span class="rounded-full bg-blue-500/10 px-2 py-0.5 text-blue-400 font-sans">
						{formatWorkoutType(workout.workout_type)}
					</span>
				</div>
			</div>
			<button
				onclick={onView}
				class="shrink-0 rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-500"
			>
				View
			</button>
		</div>
	</div>
</div>
