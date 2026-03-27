<script lang="ts">
	import { goto } from '$app/navigation';
	import PlanCard from '$lib/components/PlanCard.svelte';
	import type { TrainingPlan, Difficulty } from '$lib/types';

	let { data } = $props();

	let activeDifficulty = $state<Difficulty | null>(null);

	const filteredPlans = $derived(() => {
		if (!activeDifficulty) return data.plans as TrainingPlan[];
		return (data.plans as TrainingPlan[]).filter((p) => p.difficulty === activeDifficulty);
	});
</script>

<svelte:head>
	<title>Plans - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	<div class="mb-8 flex items-center justify-between">
		<h1 class="text-2xl font-bold text-white">Plans</h1>
		{#if data.userId}
			<a
				href="/plans/builder"
				class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-500"
			>
				+ New Plan
			</a>
		{/if}
	</div>

	<!-- Difficulty filter tabs -->
	<div class="mb-6 flex gap-1 rounded-lg border border-gray-800 bg-gray-900 p-1">
		{#each [
			{ key: null, label: 'All' },
			{ key: 'beginner', label: 'Beginner' },
			{ key: 'intermediate', label: 'Intermediate' },
			{ key: 'advanced', label: 'Advanced' }
		] as tab}
			<button
				onclick={() => (activeDifficulty = tab.key as Difficulty | null)}
				class="flex-1 rounded-md px-3 py-2 text-sm font-medium transition-colors {activeDifficulty === tab.key
					? 'bg-gray-800 text-white'
					: 'text-gray-400 hover:text-white'}"
			>
				{tab.label}
			</button>
		{/each}
	</div>

	<!-- Plans grid -->
	{#if filteredPlans().length === 0}
		<div class="py-20 text-center">
			<p class="text-gray-500">No plans found.</p>
		</div>
	{:else}
		<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
			{#each filteredPlans() as plan}
				<PlanCard
					{plan}
					onclick={() => goto(`/plans/${plan.slug}`)}
				/>
			{/each}
		</div>
	{/if}
</div>
