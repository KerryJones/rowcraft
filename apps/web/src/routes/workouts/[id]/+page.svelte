<script lang="ts">
	import { goto } from '$app/navigation';
	import WorkoutGraphHero from '$lib/components/WorkoutGraphHero.svelte';
	import StatsBar from '$lib/components/StatsBar.svelte';
	import SegmentCard from '$lib/components/SegmentCard.svelte';
	import { formatWorkoutType } from '$lib/utils/format';
	import type { Workout } from '$lib/types';

	let { data } = $props();

	const workout: Workout = $derived(data.workout);
	const isOwner = $derived(data.userId === workout.author_id);
	let forking = $state(false);
	let shareMessage = $state('');

	async function forkWorkout() {
		if (!data.userId) return;
		forking = true;
		try {
			const { supabase } = data;
			if (!supabase) return;
			const { data: forkedWorkout, error: insertError } = await supabase
				.from('workouts')
				.insert({
					author_id: data.userId,
					title: workout.title,
					description: workout.description,
					workout_type: workout.workout_type,
					segments: workout.segments,
					tags: workout.tags,
					is_public: false,
					forked_from: workout.id
				})
				.select()
				.single();

			if (insertError) throw insertError;
			await supabase.rpc('increment_fork_count', { workout_id: workout.id });
			goto(`/workouts/${forkedWorkout.id}`);
		} catch (err) {
			console.error('Fork failed:', err);
		} finally {
			forking = false;
		}
	}

	async function shareWorkout() {
		try {
			await navigator.clipboard.writeText(window.location.href);
			shareMessage = 'Link copied!';
			setTimeout(() => { shareMessage = ''; }, 2000);
		} catch {
			shareMessage = 'Copy failed — copy the URL manually';
			setTimeout(() => { shareMessage = ''; }, 3000);
		}
	}
</script>

<svelte:head>
	<title>{workout.title} - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-4xl px-4 py-6 sm:px-6 lg:px-8 space-y-6">
	<!-- Hero graph -->
	{#if workout.segments?.length > 0}
		<WorkoutGraphHero segments={workout.segments} />
	{/if}

	<!-- Title + metadata -->
	<div>
		<div class="flex items-start justify-between gap-4">
			<div>
				<div class="flex items-center gap-3">
					<h1 class="text-2xl font-bold text-white">{workout.title}</h1>
					<span class="rounded-full bg-blue-500/10 px-3 py-1 text-xs font-medium text-blue-400">
						{formatWorkoutType(workout.workout_type)}
					</span>
				</div>
				{#if workout.description}
					<p class="mt-3 text-gray-400">{workout.description}</p>
				{/if}
				{#if workout.tags?.length > 0}
					<div class="mt-3 flex flex-wrap gap-2">
						{#each workout.tags as tag}
							<span class="rounded-full border border-gray-700 px-3 py-1 text-xs text-gray-400">
								{tag}
							</span>
						{/each}
					</div>
				{/if}
			</div>

			<!-- Actions -->
			<div class="flex items-center gap-2 shrink-0">
				{#if shareMessage}
					<span class="text-sm text-emerald-400">{shareMessage}</span>
				{/if}
				<button
					onclick={shareWorkout}
					class="rounded-lg border border-gray-700 px-3 py-2 text-sm text-gray-400 transition-colors hover:border-gray-600 hover:text-white"
				>
					Share
				</button>
				{#if !isOwner && data.userId}
					<button
						onclick={forkWorkout}
						disabled={forking}
						class="rounded-lg bg-gray-800 px-3 py-2 text-sm text-white transition-colors hover:bg-gray-700 disabled:opacity-50"
					>
						{forking ? 'Forking...' : `Fork (${workout.fork_count ?? 0})`}
					</button>
				{/if}
				{#if isOwner}
					<a
						href="/builder?edit={workout.id}"
						class="rounded-lg bg-blue-600 px-3 py-2 text-sm text-white transition-colors hover:bg-blue-500"
					>
						Edit
					</a>
				{/if}
			</div>
		</div>
	</div>

	<!-- Stats bar -->
	{#if workout.segments?.length > 0}
		<StatsBar segments={workout.segments} />
	{/if}

	<!-- Segment list -->
	{#if workout.segments?.length > 0}
		<div>
			<h2 class="mb-3 text-lg font-semibold text-white">Segments</h2>
			<div class="space-y-2">
				{#each workout.segments as segment, i}
					<SegmentCard {segment} index={i} />
				{/each}
			</div>
		</div>
	{/if}

	<!-- Mobile app prompt -->
	<div class="rounded-xl border border-blue-500/20 bg-blue-500/5 p-6 text-center">
		<p class="text-lg font-semibold text-white">Ready to row?</p>
		<p class="mt-2 text-sm text-gray-400">
			Open RowCraft on your phone, connect your PM5, and start this workout with live pacing guidance.
		</p>
	</div>
</div>
