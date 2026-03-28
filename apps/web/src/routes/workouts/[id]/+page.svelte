<script lang="ts">
	import { goto } from '$app/navigation';
	import WorkoutGraph from '$lib/components/WorkoutGraph.svelte';
	import { formatWorkoutType, formatDuration, formatDistance, formatPace, formatSegmentType } from '$lib/utils/format';
	import type { Workout, WorkoutSegment } from '$lib/types';

	let { data } = $props();

	const workout: Workout = $derived(data.workout);
	const isOwner = $derived(data.userId === workout.author_id);
	let forking = $state(false);
	let shareMessage = $state('');

	function segmentDurationLabel(seg: WorkoutSegment): string {
		switch (seg.duration_type) {
			case 'time':
				return formatDuration(seg.duration_value);
			case 'distance':
				return formatDistance(seg.duration_value);
			case 'calories':
				return `${seg.duration_value} cal`;
			default:
				return String(seg.duration_value);
		}
	}

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

			// Increment fork count on original
			await supabase.rpc('increment_fork_count', { workout_id: workout.id });

			// Navigate to the forked workout
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
			// Fallback for browsers without clipboard API
			const input = document.createElement('input');
			input.value = window.location.href;
			document.body.appendChild(input);
			input.select();
			document.execCommand('copy');
			document.body.removeChild(input);
			shareMessage = 'Link copied!';
			setTimeout(() => { shareMessage = ''; }, 2000);
		}
	}
</script>

<svelte:head>
	<title>{workout.title} - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
	<!-- Header -->
	<div class="mb-8">
		<div class="flex items-start justify-between gap-4">
			<div>
				<div class="mb-2 flex items-center gap-3">
					<h1 class="text-2xl font-bold text-white">{workout.title}</h1>
					<span class="rounded-full bg-blue-500/10 px-3 py-1 text-xs font-medium text-blue-400">
						{formatWorkoutType(workout.workout_type)}
					</span>
				</div>
			</div>
			<div class="flex items-center gap-2">
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

		{#if workout.description}
			<p class="mt-4 text-gray-400">{workout.description}</p>
		{/if}

		{#if workout.tags?.length > 0}
			<div class="mt-4 flex flex-wrap gap-2">
				{#each workout.tags as tag}
					<span class="rounded-full border border-gray-700 px-3 py-1 text-xs text-gray-400">
						{tag}
					</span>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Graph -->
	{#if workout.segments?.length > 0}
		<div class="mb-8 rounded-xl border border-gray-800 bg-gray-900 p-6">
			<h2 class="mb-4 text-sm font-medium text-gray-400">Workout Preview</h2>
			<WorkoutGraph segments={workout.segments} />
		</div>
	{/if}

	<!-- Segment list -->
	<div class="mb-8">
		<h2 class="mb-4 text-lg font-semibold text-white">Segments</h2>
		<div class="space-y-3">
			{#each workout.segments ?? [] as segment, i}
				<div
					class="rounded-lg border border-gray-800 bg-gray-900 p-4 border-l-4
						{segment.type === 'work' ? 'border-l-blue-500' : ''}
						{segment.type === 'rest' ? 'border-l-gray-500' : ''}
						{segment.type === 'warmup' ? 'border-l-emerald-500' : ''}
						{segment.type === 'cooldown' ? 'border-l-yellow-500' : ''}"
				>
					<div class="flex items-center justify-between">
						<div class="flex items-center gap-3">
							<span class="text-sm font-medium text-gray-500">{i + 1}</span>
							<span class="text-sm font-semibold text-white">{formatSegmentType(segment.type)}</span>
							<span class="text-sm text-gray-400">{segmentDurationLabel(segment)}</span>
							{#if segment.repeat > 1}
								<span class="rounded bg-gray-800 px-2 py-0.5 text-xs text-gray-400">
									x{segment.repeat}
								</span>
							{/if}
						</div>
						<div class="flex items-center gap-4 text-sm text-gray-400">
							{#if segment.target_split}
								<span>Pace: {formatPace(segment.target_split.min)} - {formatPace(segment.target_split.max)}</span>
							{/if}
							{#if segment.target_stroke_rate}
								<span>SPM: {segment.target_stroke_rate.min}-{segment.target_stroke_rate.max}</span>
							{/if}
						</div>
					</div>
				</div>
			{/each}
		</div>
	</div>

	<!-- Mobile app prompt -->
	<div class="rounded-xl border border-blue-500/20 bg-blue-500/5 p-6 text-center">
		<p class="text-lg font-semibold text-white">Ready to row?</p>
		<p class="mt-2 text-sm text-gray-400">
			Open RowCraft on your phone, connect your PM5, and start this workout with live pacing guidance.
		</p>
	</div>
</div>
