<script lang="ts">
	import { goto } from '$app/navigation';
	import WorkoutPicker from '$lib/components/WorkoutPicker.svelte';
	import { formatDifficulty } from '$lib/utils/format';
	import type { Difficulty, PlanWeek, PlanSession } from '$lib/types';

	let { data } = $props();

	// Form state — pre-populate if editing (intentionally captures initial data for form editing)
	// svelte-ignore state_referenced_locally
	let title = $state(data.plan?.title ?? '');
	// svelte-ignore state_referenced_locally
	let description = $state(data.plan?.description ?? '');
	// svelte-ignore state_referenced_locally
	let difficulty = $state<Difficulty>(data.plan?.difficulty ?? 'beginner');
	// svelte-ignore state_referenced_locally
	let tags = $state<string[]>(data.plan?.tags ?? []);
	let tagInput = $state('');
	// svelte-ignore state_referenced_locally
	let weeks = $state<PlanWeek[]>(data.plan?.weeks ?? [
		{ week_number: 1, title: '', sessions: [{ day_label: 'Day 1', workout_id: '', notes: null }] }
	]);
	let saving = $state(false);
	let errors = $state<Record<string, string>>({});

	const isEdit = $derived(!!data.plan);
	const derivedSlug = $derived(title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''));
	const slug = $derived(isEdit && data.plan?.slug ? data.plan.slug : derivedSlug);

	let expandedWeek = $state(0);

	// Workout map for preview
	const workoutMap = $derived(() => {
		const map: Record<string, string> = {};
		for (const w of data.workouts) {
			map[w.id] = w.title;
		}
		return map;
	});

	function addWeek() {
		const weekNumber = weeks.length + 1;
		weeks = [...weeks, {
			week_number: weekNumber,
			title: '',
			sessions: [{ day_label: 'Day 1', workout_id: '', notes: null }]
		}];
		expandedWeek = weeks.length - 1;
	}

	function removeWeek(index: number) {
		weeks = weeks.filter((_, i) => i !== index).map((w, i) => ({ ...w, week_number: i + 1 }));
		if (expandedWeek >= weeks.length) expandedWeek = Math.max(0, weeks.length - 1);
	}

	function addSession(weekIndex: number) {
		const week = weeks[weekIndex];
		const dayNumber = week.sessions.length + 1;
		weeks = weeks.map((w, i) =>
			i === weekIndex
				? { ...w, sessions: [...w.sessions, { day_label: `Day ${dayNumber}`, workout_id: '', notes: null }] }
				: w
		);
	}

	function removeSession(weekIndex: number, sessionIndex: number) {
		weeks = weeks.map((w, i) =>
			i === weekIndex
				? { ...w, sessions: w.sessions.filter((_, si) => si !== sessionIndex) }
				: w
		);
	}

	function updateSessionField(weekIndex: number, sessionIndex: number, field: keyof PlanSession, value: string | null) {
		weeks = weeks.map((w, wi) =>
			wi === weekIndex
				? {
						...w,
						sessions: w.sessions.map((s, si) =>
							si === sessionIndex ? { ...s, [field]: value } : s
						)
					}
				: w
		);
	}

	function updateWeekTitle(weekIndex: number, value: string) {
		weeks = weeks.map((w, i) => (i === weekIndex ? { ...w, title: value } : w));
	}

	function addTag() {
		const tag = tagInput.trim().toLowerCase();
		if (tag && !tags.includes(tag)) {
			tags = [...tags, tag];
		}
		tagInput = '';
	}

	function removeTag(tag: string) {
		tags = tags.filter((t) => t !== tag);
	}

	function validate(): boolean {
		const newErrors: Record<string, string> = {};

		if (!title.trim()) newErrors.title = 'Title is required';
		if (!isEdit && !slug) newErrors.title = 'Title must contain at least one letter or number';
		if (weeks.length === 0) newErrors.weeks = 'Add at least one week';

		for (let wi = 0; wi < weeks.length; wi++) {
			if (weeks[wi].sessions.length === 0) {
				newErrors[`week_${wi}`] = 'Each week needs at least one session';
			}
			for (let si = 0; si < weeks[wi].sessions.length; si++) {
				if (!weeks[wi].sessions[si].workout_id) {
					newErrors[`week_${wi}_session_${si}`] = 'Select a workout';
				}
			}
		}

		errors = newErrors;
		return Object.keys(newErrors).length === 0;
	}

	async function savePlan() {
		if (!validate()) return;
		saving = true;

		try {
			const { supabase, session } = data;
			if (!supabase || !session?.user) {
				goto('/auth/login');
				return;
			}

			// Compute duration_weeks and sessions_per_week
			const duration_weeks = weeks.length;
			const sessions_per_week = weeks.length > 0
				? Math.round(weeks.reduce((sum, w) => sum + w.sessions.length, 0) / weeks.length)
				: 0;

			const planData = {
				title: title.trim(),
				slug,
				description: description.trim(),
				difficulty,
				duration_weeks,
				sessions_per_week,
				tags,
				weeks,
				is_active: true
			};

			if (isEdit && data.plan) {
				const { error } = await supabase
					.from('training_plans')
					.update(planData)
					.eq('id', data.plan.id);

				if (error) throw error;
				goto(`/plans/${slug}`);
			} else {
				const { error } = await supabase
					.from('training_plans')
					.insert(planData);

				if (error) throw error;
				goto(`/plans/${slug}`);
			}
		} catch (err) {
			console.error('Save failed:', err);
			errors = { save: 'Failed to save plan. Please try again.' };
		} finally {
			saving = false;
		}
	}
</script>

<svelte:head>
	<title>{isEdit ? 'Edit Plan' : 'New Plan'} - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
	<h1 class="mb-8 text-2xl font-bold text-white">{isEdit ? 'Edit Plan' : 'Plan Builder'}</h1>

	<div class="grid gap-8 lg:grid-cols-[1fr,380px]">
		<!-- Left column: Form -->
		<div class="space-y-6">
			<!-- Title -->
			<div>
				<label for="title" class="mb-1.5 block text-sm font-medium text-gray-300">Title</label>
				<input
					id="title"
					type="text"
					bind:value={title}
					placeholder="e.g., Pete Plan"
					class="w-full rounded-lg border border-gray-700 bg-gray-900 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
				/>
				{#if errors.title}
					<p class="mt-1 text-sm text-red-400">{errors.title}</p>
				{/if}
			</div>

			<!-- Slug (read-only, derived) -->
			<div>
				<label for="slug" class="mb-1.5 block text-sm font-medium text-gray-300">Slug</label>
				<input
					id="slug"
					type="text"
					value={slug}
					placeholder="Generated from title"
					disabled
					class="w-full rounded-lg border border-gray-700 bg-gray-950 px-4 py-2.5 text-sm text-gray-500 placeholder-gray-600"
				/>
			</div>

			<!-- Description -->
			<div>
				<label for="description" class="mb-1.5 block text-sm font-medium text-gray-300">Description</label>
				<textarea
					id="description"
					bind:value={description}
					rows="3"
					placeholder="Describe the training plan..."
					class="w-full rounded-lg border border-gray-700 bg-gray-900 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
				></textarea>
			</div>

			<!-- Difficulty -->
			<div>
				<span class="mb-1.5 block text-sm font-medium text-gray-300">Difficulty</span>
				<div class="flex flex-wrap gap-2">
					{#each ['beginner', 'intermediate', 'advanced'] as d}
						<button
							type="button"
							onclick={() => (difficulty = d as Difficulty)}
							class="rounded-lg px-3 py-2 text-sm font-medium transition-colors {difficulty === d
								? 'bg-blue-600 text-white'
								: 'border border-gray-700 bg-gray-900 text-gray-400 hover:border-gray-600 hover:text-white'}"
						>
							{formatDifficulty(d)}
						</button>
					{/each}
				</div>
			</div>

			<!-- Tags -->
			<div>
				<span class="mb-1.5 block text-sm font-medium text-gray-300">Tags</span>
				<div class="flex gap-2">
					<input
						type="text"
						bind:value={tagInput}
						placeholder="Add a tag..."
						onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addTag(); } }}
						class="flex-1 rounded-lg border border-gray-700 bg-gray-900 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
					/>
					<button
						type="button"
						onclick={addTag}
						class="rounded-lg border border-gray-700 bg-gray-900 px-3 py-2.5 text-sm text-gray-400 transition-colors hover:border-gray-600 hover:text-white"
					>
						+
					</button>
				</div>
				{#if tags.length > 0}
					<div class="mt-2 flex flex-wrap gap-1.5">
						{#each tags as tag}
							<span class="inline-flex items-center gap-1 rounded-full bg-gray-800 px-2.5 py-0.5 text-xs text-gray-300">
								{tag}
								<button type="button" onclick={() => removeTag(tag)} class="text-gray-500 hover:text-white">&times;</button>
							</span>
						{/each}
					</div>
				{/if}
			</div>

			<!-- Weeks -->
			<div>
				<div class="mb-3 flex items-center justify-between">
					<span class="text-sm font-medium text-gray-300">Weeks</span>
					{#if errors.weeks}
						<p class="text-sm text-red-400">{errors.weeks}</p>
					{/if}
				</div>

				<div class="space-y-3">
					{#each weeks as week, wi}
						<div class="rounded-xl border border-gray-800 bg-gray-900 overflow-hidden">
							<!-- Week header -->
							<div class="flex items-center gap-3 px-4 py-3">
								<button
									type="button"
									onclick={() => (expandedWeek = expandedWeek === wi ? -1 : wi)}
									class="flex flex-1 items-center gap-3 text-left"
								>
									<svg
										class="h-4 w-4 text-gray-500 transition-transform {expandedWeek === wi ? 'rotate-180' : ''}"
										fill="none" stroke="currentColor" viewBox="0 0 24 24"
									>
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
									</svg>
									<span class="text-sm font-medium text-gray-500">Week {week.week_number}</span>
								</button>
								<input
									type="text"
									value={week.title}
									oninput={(e) => updateWeekTitle(wi, e.currentTarget.value)}
									placeholder="Week title..."
									class="flex-1 rounded border border-gray-700 bg-gray-950 px-2 py-1 text-sm text-white placeholder-gray-600 outline-none focus:border-blue-500"
								/>
								<button
									type="button"
									onclick={() => removeWeek(wi)}
									class="text-sm text-gray-500 hover:text-red-400"
								>
									&times;
								</button>
							</div>

							<!-- Week sessions -->
							{#if expandedWeek === wi}
								<div class="border-t border-gray-800 px-4 py-4 space-y-3">
									{#each week.sessions as session, si}
										<div class="rounded-lg border border-gray-800 bg-gray-950 p-3 space-y-2">
											<div class="flex items-center gap-3">
												<input
													type="text"
													value={session.day_label}
													oninput={(e) => updateSessionField(wi, si, 'day_label', e.currentTarget.value)}
													class="w-24 rounded border border-gray-700 bg-gray-900 px-2 py-1 text-sm text-white outline-none focus:border-blue-500"
												/>
												<div class="flex-1">
													<WorkoutPicker
														workouts={data.workouts}
														value={session.workout_id}
														onselect={(id) => updateSessionField(wi, si, 'workout_id', id)}
													/>
												</div>
												<button
													type="button"
													onclick={() => removeSession(wi, si)}
													class="text-sm text-gray-500 hover:text-red-400"
												>
													&times;
												</button>
											</div>
											<input
												type="text"
												value={session.notes ?? ''}
												oninput={(e) => updateSessionField(wi, si, 'notes', e.currentTarget.value || null)}
												placeholder="Notes (optional)"
												class="w-full rounded border border-gray-700 bg-gray-900 px-2 py-1 text-sm text-white placeholder-gray-600 outline-none focus:border-blue-500"
											/>
											{#if errors[`week_${wi}_session_${si}`]}
												<p class="text-xs text-red-400">{errors[`week_${wi}_session_${si}`]}</p>
											{/if}
										</div>
									{/each}

									<button
										type="button"
										onclick={() => addSession(wi)}
										class="w-full rounded-lg border border-dashed border-gray-700 py-2 text-sm text-gray-500 transition-colors hover:border-gray-600 hover:text-gray-400"
									>
										+ Add Session
									</button>

									{#if errors[`week_${wi}`]}
										<p class="text-sm text-red-400">{errors[`week_${wi}`]}</p>
									{/if}
								</div>
							{/if}
						</div>
					{/each}
				</div>

				<button
					type="button"
					onclick={addWeek}
					class="mt-3 w-full rounded-lg border border-dashed border-gray-700 py-3 text-sm font-medium text-gray-500 transition-colors hover:border-gray-600 hover:text-gray-400"
				>
					+ Add Week
				</button>
			</div>

			<!-- Save -->
			<div class="flex items-center justify-between border-t border-gray-800 pt-6">
				<a href="/plans" class="rounded-lg border border-gray-700 px-4 py-2.5 text-sm text-gray-400 transition-colors hover:border-gray-600 hover:text-white">
					Cancel
				</a>
				<div class="flex gap-3">
					{#if errors.save}
						<p class="self-center text-sm text-red-400">{errors.save}</p>
					{/if}
					<button
						onclick={savePlan}
						disabled={saving}
						class="rounded-lg bg-blue-600 px-6 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-500 disabled:opacity-50"
					>
						{saving ? 'Saving...' : isEdit ? 'Update Plan' : 'Save Plan'}
					</button>
				</div>
			</div>
		</div>

		<!-- Right column: Preview -->
		<div class="lg:sticky lg:top-24 lg:self-start">
			<div class="rounded-xl border border-gray-800 bg-gray-900 p-6">
				<h2 class="mb-4 text-sm font-medium text-gray-400">Plan Structure</h2>
				{#if weeks.length > 0}
					<div class="space-y-4">
						{#each weeks as week}
							<div>
								<p class="mb-1 text-sm font-semibold text-white">
									Week {week.week_number}{week.title ? `: ${week.title}` : ''}
								</p>
								{#each week.sessions as session}
									<p class="ml-4 text-sm text-gray-400">
										{session.day_label}: {workoutMap()[session.workout_id] ?? (session.workout_id ? '...' : 'Not selected')}
									</p>
								{/each}
							</div>
						{/each}
					</div>
				{:else}
					<div class="flex h-48 items-center justify-center text-sm text-gray-600">
						Add weeks to see preview
					</div>
				{/if}
			</div>
		</div>
	</div>
</div>
