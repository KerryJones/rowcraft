<script lang="ts">
	import type { Workout } from '$lib/types';
	import { formatWorkoutType } from '$lib/utils/format';

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

	const descriptionExcerpt = $derived(
		workout.description && workout.description.length > 100
			? workout.description.slice(0, 100) + '...'
			: workout.description ?? ''
	);
</script>

<button
	{onclick}
	class="group w-full rounded-xl border border-gray-800 bg-gray-900 p-5 text-left transition-colors hover:border-gray-700 hover:bg-gray-800/50"
>
	<div class="mb-2 flex items-start justify-between gap-2">
		<h3 class="font-semibold text-white group-hover:text-blue-400 transition-colors">
			{workout.title}
		</h3>
		<span class="shrink-0 rounded-full px-2.5 py-0.5 text-xs font-medium {badgeClass}">
			{formatWorkoutType(workout.workout_type)}
		</span>
	</div>

	{#if descriptionExcerpt}
		<p class="mb-3 text-sm leading-relaxed text-gray-400">{descriptionExcerpt}</p>
	{/if}

	{#if workout.tags?.length > 0}
		<div class="mb-3 flex flex-wrap gap-1.5">
			{#each workout.tags.slice(0, 4) as tag}
				<span class="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-400">{tag}</span>
			{/each}
			{#if workout.tags.length > 4}
				<span class="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-500">
					+{workout.tags.length - 4}
				</span>
			{/if}
		</div>
	{/if}

	<div class="flex items-center gap-4 text-xs text-gray-500">
		{#if workout.fork_count > 0}
			<span class="flex items-center gap-1">
				<svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
				</svg>
				{workout.fork_count}
			</span>
		{/if}
	</div>
</button>
