<script lang="ts">
	import { formatDifficulty } from '$lib/utils/format';
	import type { TrainingPlan, PlanWeek } from '$lib/types';

	let { data } = $props();

	const plan: TrainingPlan = data.plan;
	const workoutMap: Record<string, string> = data.workoutMap;

	let expandedWeek = $state<number>(0);

	const difficultyBadgeColors: Record<string, string> = {
		beginner: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
		intermediate: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
		advanced: 'bg-red-500/10 text-red-400 border-red-500/20'
	};

	const badgeClass = $derived(difficultyBadgeColors[plan.difficulty] ?? 'bg-gray-500/10 text-gray-400 border-gray-500/20');

	function toggleWeek(index: number) {
		expandedWeek = expandedWeek === index ? -1 : index;
	}
</script>

<svelte:head>
	<title>{plan.title} - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
	<!-- Hero section -->
	<div class="mb-8">
		<div class="flex items-start justify-between gap-4">
			<div>
				<div class="mb-2 flex items-center gap-3">
					<h1 class="text-2xl font-bold text-white">{plan.title}</h1>
					<span class="rounded-full border px-3 py-1 text-xs font-medium {badgeClass}">
						{formatDifficulty(plan.difficulty)}
					</span>
				</div>
				<p class="text-sm text-gray-500">
					{plan.duration_weeks} weeks &middot; {plan.sessions_per_week}x/week
				</p>
			</div>
			{#if data.userId}
				<a
					href="/plans/builder?edit={plan.id}"
					class="rounded-lg bg-blue-600 px-3 py-2 text-sm text-white transition-colors hover:bg-blue-500"
				>
					Edit
				</a>
			{/if}
		</div>

		{#if plan.description}
			<p class="mt-4 text-gray-400">{plan.description}</p>
		{/if}

		{#if plan.tags?.length > 0}
			<div class="mt-4 flex flex-wrap gap-2">
				{#each plan.tags as tag}
					<span class="rounded-full border border-gray-700 px-3 py-1 text-xs text-gray-400">
						{tag}
					</span>
				{/each}
			</div>
		{/if}
	</div>

	<!-- Week accordion -->
	<div class="space-y-3">
		{#each plan.weeks ?? [] as week, i}
			<div class="rounded-xl border border-gray-800 bg-gray-900 overflow-hidden">
				<button
					onclick={() => toggleWeek(i)}
					class="flex w-full items-center justify-between px-5 py-4 text-left transition-colors hover:bg-gray-800/50"
				>
					<div class="flex items-center gap-3">
						<span class="text-sm font-medium text-gray-500">Week {week.week_number}</span>
						<span class="font-semibold text-white">{week.title}</span>
						<span class="text-sm text-gray-500">{(week.sessions ?? []).length} sessions</span>
					</div>
					<svg
						class="h-5 w-5 text-gray-500 transition-transform {expandedWeek === i ? 'rotate-180' : ''}"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</button>

				{#if expandedWeek === i}
					<div class="border-t border-gray-800 px-5 py-4">
						<div class="space-y-3">
							{#each week.sessions ?? [] as session}
								<div class="flex items-center gap-4 rounded-lg border border-gray-800 bg-gray-950 px-4 py-3">
									<span class="text-sm font-medium text-gray-500">{session.day_label}</span>
									<span class="font-medium text-white">
										{workoutMap[session.workout_id] ?? 'Unknown Workout'}
									</span>
									{#if session.notes}
										<span class="text-sm text-gray-500">&mdash; {session.notes}</span>
									{/if}
								</div>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		{/each}
	</div>
</div>
