<script lang="ts">
	import type { TrainingPlan } from '$lib/types';
	import { formatDifficulty } from '$lib/utils/format';

	interface Props {
		plan: TrainingPlan;
		onclick: () => void;
	}

	let { plan, onclick }: Props = $props();

	const difficultyBadgeColors: Record<string, string> = {
		beginner: 'bg-emerald-500/10 text-emerald-400',
		intermediate: 'bg-amber-500/10 text-amber-400',
		advanced: 'bg-red-500/10 text-red-400'
	};

	const badgeClass = $derived(difficultyBadgeColors[plan.difficulty] ?? 'bg-gray-500/10 text-gray-400');

	const descriptionExcerpt = $derived(
		plan.description && plan.description.length > 100
			? plan.description.slice(0, 100) + '...'
			: plan.description ?? ''
	);
</script>

<button
	{onclick}
	class="group w-full rounded-xl border border-gray-800 bg-gray-900 p-5 text-left transition-colors hover:border-gray-700 hover:bg-gray-800/50"
>
	<div class="mb-2 flex items-start justify-between gap-2">
		<h3 class="font-semibold text-white group-hover:text-blue-400 transition-colors">
			{plan.title}
		</h3>
		<span class="shrink-0 rounded-full px-2.5 py-0.5 text-xs font-medium {badgeClass}">
			{formatDifficulty(plan.difficulty)}
		</span>
	</div>

	<p class="mb-3 text-sm text-gray-500">
		{plan.duration_weeks} weeks &middot; {plan.sessions_per_week}x/week
	</p>

	{#if descriptionExcerpt}
		<p class="mb-3 text-sm leading-relaxed text-gray-400">{descriptionExcerpt}</p>
	{/if}

	{#if plan.tags?.length > 0}
		<div class="flex flex-wrap gap-1.5">
			{#each plan.tags.slice(0, 4) as tag}
				<span class="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-400">{tag}</span>
			{/each}
			{#if plan.tags.length > 4}
				<span class="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-500">
					+{plan.tags.length - 4}
				</span>
			{/if}
		</div>
	{/if}
</button>
