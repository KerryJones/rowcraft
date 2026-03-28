<script lang="ts">
	import { goto } from '$app/navigation';
	import WorkoutCard from '$lib/components/WorkoutCard.svelte';
	import WodCard from '$lib/components/WodCard.svelte';
	import { formatWorkoutType } from '$lib/utils/format';
	import type { Workout } from '$lib/types';

	let { data } = $props();

	let searchQuery = $state('');
	// svelte-ignore state_referenced_locally
	let activeTab = $state<'all' | 'mine' | 'community'>(data.tab as 'all' | 'mine' | 'community');
	let selectedTags = $state<string[]>([]);

	const allTags = $derived.by(() => {
		const tagSet = new Set<string>();
		data.workouts.forEach((w: Workout) => w.tags?.forEach((t: string) => tagSet.add(t)));
		return Array.from(tagSet).sort();
	});

	const filteredWorkouts = $derived.by(() => {
		let result = data.workouts as Workout[];

		if (searchQuery) {
			const q = searchQuery.toLowerCase();
			result = result.filter(
				(w) =>
					w.title.toLowerCase().includes(q) ||
					w.description?.toLowerCase().includes(q) ||
					w.tags?.some((t) => t.toLowerCase().includes(q))
			);
		}

		if (selectedTags.length > 0) {
			result = result.filter((w) => selectedTags.some((tag) => w.tags?.includes(tag)));
		}

		return result;
	});

	// WOD — deterministic daily pick from public workouts, with shuffle override
	function dateHash(): number {
		const d = new Date();
		return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
	}

	function pickWod(seed: number): Workout | null {
		const publicWorkouts = (data.workouts as Workout[]).filter((w) => w.is_public && w.segments?.length > 0);
		if (publicWorkouts.length === 0) return null;
		return publicWorkouts[seed % publicWorkouts.length];
	}

	let wodSeed = $state(dateHash());
	const wodWorkout = $derived(pickWod(wodSeed));

	function shuffleWod() {
		wodSeed = Math.floor(Math.random() * 1000000);
	}

	function switchTab(tab: 'all' | 'mine' | 'community') {
		activeTab = tab;
		goto(`/workouts?tab=${tab}`, { replaceState: true });
	}

	function toggleTag(tag: string) {
		if (selectedTags.includes(tag)) {
			selectedTags = selectedTags.filter((t) => t !== tag);
		} else {
			selectedTags = [...selectedTags, tag];
		}
	}
</script>

<svelte:head>
	<title>Workouts - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
	<div class="mb-8 flex items-center justify-between">
		<h1 class="text-2xl font-bold text-white">Workouts</h1>
		{#if data.userId}
			<a
				href="/builder"
				class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-500"
			>
				New Workout
			</a>
		{/if}
	</div>

	<!-- WOD -->
	{#if wodWorkout}
		<div class="mb-8">
			<WodCard
				workout={wodWorkout}
				onShuffle={shuffleWod}
				onView={() => goto(`/workouts/${wodWorkout.id}`)}
			/>
		</div>
	{/if}

	<!-- Search -->
	<div class="mb-6">
		<input
			type="text"
			bind:value={searchQuery}
			placeholder="Search workouts..."
			class="w-full rounded-lg border border-gray-700 bg-gray-900 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none transition-colors focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
		/>
	</div>

	<!-- Tabs -->
	<div class="mb-6 flex gap-1 rounded-lg border border-gray-800 bg-gray-900 p-1">
		{#each [
			{ key: 'all', label: 'All' },
			{ key: 'mine', label: 'My Workouts' },
			{ key: 'community', label: 'Community' }
		] as tab}
			<button
				onclick={() => switchTab(tab.key as 'all' | 'mine' | 'community')}
				class="flex-1 rounded-md px-3 py-2 text-sm font-medium transition-colors {activeTab === tab.key
					? 'bg-gray-800 text-white'
					: 'text-gray-400 hover:text-white'}"
			>
				{tab.label}
			</button>
		{/each}
	</div>

	<!-- Tag chips -->
	{#if allTags.length > 0}
		<div class="mb-6 flex flex-wrap gap-2">
			{#each allTags as tag}
				<button
					onclick={() => toggleTag(tag)}
					class="rounded-full px-3 py-1 text-xs font-medium transition-colors {selectedTags.includes(tag)
						? 'bg-blue-600 text-white'
						: 'border border-gray-700 bg-gray-900 text-gray-400 hover:border-gray-600 hover:text-white'}"
				>
					{tag}
				</button>
			{/each}
		</div>
	{/if}

	<!-- Workout grid -->
	{#if filteredWorkouts.length === 0}
		<div class="py-20 text-center">
			<p class="text-gray-500">No workouts found.</p>
			{#if searchQuery || selectedTags.length > 0}
				<button
					onclick={() => { searchQuery = ''; selectedTags = []; }}
					class="mt-2 text-sm text-blue-500 hover:text-blue-400"
				>
					Clear filters
				</button>
			{/if}
		</div>
	{:else}
		<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
			{#each filteredWorkouts as workout}
				<WorkoutCard
					{workout}
					onclick={() => goto(`/workouts/${workout.id}`)}
				/>
			{/each}
		</div>
	{/if}
</div>
