<script lang="ts">
	import { goto } from '$app/navigation';
	import IntervalBlock from '$lib/components/IntervalBlock.svelte';
	import WorkoutGraph from '$lib/components/WorkoutGraph.svelte';
	import type { WorkoutSegment, WorkoutType, SegmentType } from '$lib/types';

	let { data } = $props();

	let title = $state('');
	let description = $state('');
	let workoutType = $state<WorkoutType>('intervals');
	let isPublic = $state(false);
	let segments = $state<WorkoutSegment[]>([]);
	let saving = $state(false);
	let errors = $state<Record<string, string>>({});

	const workoutTypes: { value: WorkoutType; label: string }[] = [
		{ value: 'intervals', label: 'Intervals' },
		{ value: 'single_distance', label: 'Distance' },
		{ value: 'single_time', label: 'Time' },
		{ value: 'variable_intervals', label: 'Variable' }
	];

	function addSegment(type: SegmentType) {
		const newSegment: WorkoutSegment = {
			type,
			duration_type: 'time',
			duration_value: type === 'rest' ? 60 : 300,
			target_split: null,
			target_stroke_rate: null,
			target_hr_zone: null,
			repeat: 1
		};
		segments = [...segments, newSegment];
	}

	function updateSegment(index: number, updated: WorkoutSegment) {
		segments = segments.map((s, i) => (i === index ? updated : s));
	}

	function deleteSegment(index: number) {
		segments = segments.filter((_, i) => i !== index);
	}

	function moveSegment(index: number, direction: 'up' | 'down') {
		const newIndex = direction === 'up' ? index - 1 : index + 1;
		if (newIndex < 0 || newIndex >= segments.length) return;
		const newSegments = [...segments];
		[newSegments[index], newSegments[newIndex]] = [newSegments[newIndex], newSegments[index]];
		segments = newSegments;
	}

	function validate(): boolean {
		const newErrors: Record<string, string> = {};

		if (!title.trim()) {
			newErrors.title = 'Title is required';
		}
		if (segments.length === 0) {
			newErrors.segments = 'Add at least one segment';
		}
		segments.forEach((seg, i) => {
			if (seg.duration_value <= 0) {
				newErrors[`segment_${i}`] = 'Duration must be greater than 0';
			}
		});

		errors = newErrors;
		return Object.keys(newErrors).length === 0;
	}

	async function saveWorkout() {
		if (!validate()) return;
		saving = true;

		try {
			const { supabase, session } = data;
			if (!supabase || !session?.user) {
				goto('/auth/login');
				return;
			}

			const { data: workout, error } = await supabase.from('workouts').insert({
				author_id: session.user.id,
				title: title.trim(),
				description: description.trim(),
				workout_type: workoutType,
				segments,
				tags: [],
				is_public: isPublic
			}).select().single();

			if (error) throw error;
			goto(`/workouts/${workout.id}`);
		} catch (err) {
			errors = { save: 'Failed to save workout. Please try again.' };
		} finally {
			saving = false;
		}
	}
</script>

<svelte:head>
	<title>Workout Builder - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
	<h1 class="mb-8 text-2xl font-bold text-white">Workout Builder</h1>

	<div class="grid gap-8 lg:grid-cols-[1fr,380px]">
		<!-- Builder form -->
		<div class="space-y-6">
			<!-- Title -->
			<div>
				<label for="title" class="mb-1.5 block text-sm font-medium text-gray-300">Title</label>
				<input
					id="title"
					type="text"
					bind:value={title}
					placeholder="e.g., 8x500m Intervals"
					class="w-full rounded-lg border border-gray-700 bg-gray-900 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
				/>
				{#if errors.title}
					<p class="mt-1 text-sm text-red-400">{errors.title}</p>
				{/if}
			</div>

			<!-- Description -->
			<div>
				<label for="description" class="mb-1.5 block text-sm font-medium text-gray-300">Description</label>
				<textarea
					id="description"
					bind:value={description}
					rows="3"
					placeholder="Describe the workout..."
					class="w-full rounded-lg border border-gray-700 bg-gray-900 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
				></textarea>
			</div>

			<!-- Workout type -->
			<div>
				<span class="mb-1.5 block text-sm font-medium text-gray-300">Workout Type</span>
				<div class="flex flex-wrap gap-2">
					{#each workoutTypes as wt}
						<button
							onclick={() => (workoutType = wt.value)}
							class="rounded-lg px-3 py-2 text-sm font-medium transition-colors {workoutType === wt.value
								? 'bg-blue-600 text-white'
								: 'border border-gray-700 bg-gray-900 text-gray-400 hover:border-gray-600 hover:text-white'}"
						>
							{wt.label}
						</button>
					{/each}
				</div>
			</div>

			<!-- Segments -->
			<div>
				<div class="mb-3 flex items-center justify-between">
					<span class="text-sm font-medium text-gray-300">Segments</span>
					{#if errors.segments}
						<p class="text-sm text-red-400">{errors.segments}</p>
					{/if}
				</div>

				<div class="space-y-3">
					{#each segments as segment, i}
						<IntervalBlock
							{segment}
							index={i}
							total={segments.length}
							onUpdate={(updated) => updateSegment(i, updated)}
							onDelete={() => deleteSegment(i)}
							onMoveUp={() => moveSegment(i, 'up')}
							onMoveDown={() => moveSegment(i, 'down')}
							error={errors[`segment_${i}`] ?? null}
						/>
					{/each}
				</div>

				<!-- Add segment buttons -->
				<div class="mt-4 flex flex-wrap gap-2">
					<button
						onclick={() => addSegment('work')}
						class="rounded-lg border border-blue-500/30 bg-blue-500/10 px-3 py-2 text-sm font-medium text-blue-400 transition-colors hover:bg-blue-500/20"
					>
						+ Work
					</button>
					<button
						onclick={() => addSegment('rest')}
						class="rounded-lg border border-gray-600/30 bg-gray-600/10 px-3 py-2 text-sm font-medium text-gray-400 transition-colors hover:bg-gray-600/20"
					>
						+ Rest
					</button>
					<button
						onclick={() => addSegment('warmup')}
						class="rounded-lg border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-sm font-medium text-emerald-400 transition-colors hover:bg-emerald-500/20"
					>
						+ Warm Up
					</button>
					<button
						onclick={() => addSegment('cooldown')}
						class="rounded-lg border border-yellow-500/30 bg-yellow-500/10 px-3 py-2 text-sm font-medium text-yellow-400 transition-colors hover:bg-yellow-500/20"
					>
						+ Cool Down
					</button>
				</div>
			</div>

			<!-- Save -->
			<div class="flex items-center justify-between border-t border-gray-800 pt-6">
				<label class="flex items-center gap-2 text-sm text-gray-400">
					<input
						type="checkbox"
						bind:checked={isPublic}
						class="h-4 w-4 rounded border-gray-600 bg-gray-800 text-blue-600"
					/>
					Make public
				</label>
				<div class="flex gap-3">
					{#if errors.save}
						<p class="self-center text-sm text-red-400">{errors.save}</p>
					{/if}
					<button
						onclick={saveWorkout}
						disabled={saving}
						class="rounded-lg bg-blue-600 px-6 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-500 disabled:opacity-50"
					>
						{saving ? 'Saving...' : 'Save Workout'}
					</button>
				</div>
			</div>
		</div>

		<!-- Live preview -->
		<div class="lg:sticky lg:top-24">
			<div class="rounded-xl border border-gray-800 bg-gray-900 p-6">
				<h2 class="mb-4 text-sm font-medium text-gray-400">Preview</h2>
				{#if segments.length > 0}
					<WorkoutGraph {segments} />
				{:else}
					<div class="flex h-48 items-center justify-center text-sm text-gray-600">
						Add segments to see preview
					</div>
				{/if}
			</div>
		</div>
	</div>
</div>
