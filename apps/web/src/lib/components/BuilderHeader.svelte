<script lang="ts">
	import type { WorkoutType } from '$lib/types';

	interface Props {
		title: string;
		description: string;
		workoutType: WorkoutType;
		tags: string[];
		isPublic: boolean;
		onTitleChange: (value: string) => void;
		onDescriptionChange: (value: string) => void;
		onWorkoutTypeChange: (value: WorkoutType) => void;
		onTagsChange: (value: string[]) => void;
		onPublicChange: (value: boolean) => void;
	}

	let {
		title, description, workoutType, tags, isPublic,
		onTitleChange, onDescriptionChange, onWorkoutTypeChange, onTagsChange, onPublicChange
	}: Props = $props();

	let expanded = $state(true);
	let tagInput = $state('');

	const workoutTypes: { value: WorkoutType; label: string }[] = [
		{ value: 'intervals', label: 'Intervals' },
		{ value: 'single_distance', label: 'Distance' },
		{ value: 'single_time', label: 'Time' },
		{ value: 'variable_intervals', label: 'Variable' }
	];

	function addTag(e: KeyboardEvent) {
		if (e.key === 'Enter' && tagInput.trim()) {
			e.preventDefault();
			const newTag = tagInput.trim().toLowerCase();
			if (!tags.includes(newTag)) {
				onTagsChange([...tags, newTag]);
			}
			tagInput = '';
		}
	}

	function removeTag(tag: string) {
		onTagsChange(tags.filter((t) => t !== tag));
	}
</script>

<div class="rounded-xl border border-gray-800 bg-gray-900">
	<!-- Collapsed header -->
	<button
		type="button"
		class="flex w-full items-center justify-between px-5 py-3"
		onclick={() => (expanded = !expanded)}
	>
		<div class="flex items-center gap-3">
			{#if title}
				<h2 class="text-lg font-semibold text-white">{title}</h2>
			{:else}
				<h2 class="text-lg text-gray-500">Untitled Workout</h2>
			{/if}
		</div>
		<svg
			class="h-5 w-5 text-gray-500 transition-transform {expanded ? 'rotate-180' : ''}"
			fill="none" stroke="currentColor" viewBox="0 0 24 24"
		>
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
		</svg>
	</button>

	<!-- Expanded form -->
	{#if expanded}
		<div class="border-t border-gray-800 px-5 py-4 space-y-4">
			<div>
				<label for="builder-title" class="mb-1 block text-xs text-gray-500">Title</label>
				<input
					id="builder-title"
					type="text"
					value={title}
					oninput={(e) => onTitleChange((e.target as HTMLInputElement).value)}
					placeholder="e.g., 8x500m Intervals"
					class="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
				/>
			</div>

			<div>
				<label for="builder-desc" class="mb-1 block text-xs text-gray-500">Description</label>
				<textarea
					id="builder-desc"
					value={description}
					oninput={(e) => onDescriptionChange((e.target as HTMLTextAreaElement).value)}
					rows="2"
					placeholder="Describe the workout..."
					class="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
				></textarea>
			</div>

			<div class="flex flex-wrap items-end gap-6">
				<div>
					<span class="mb-1 block text-xs text-gray-500">Type</span>
					<div class="flex gap-1.5">
						{#each workoutTypes as wt}
							<button
								type="button"
								onclick={() => onWorkoutTypeChange(wt.value)}
								class="rounded-lg px-3 py-1.5 text-xs font-medium transition-colors {workoutType === wt.value
									? 'bg-blue-600 text-white'
									: 'border border-gray-700 bg-gray-800 text-gray-400 hover:text-white'}"
							>
								{wt.label}
							</button>
						{/each}
					</div>
				</div>

				<div class="flex-1">
					<span class="mb-1 block text-xs text-gray-500">Tags</span>
					<div class="flex flex-wrap items-center gap-1.5">
						{#each tags as tag}
							<span class="flex items-center gap-1 rounded-full bg-gray-800 px-2.5 py-0.5 text-xs text-gray-400">
								{tag}
								<button type="button" onclick={() => removeTag(tag)} class="text-gray-600 hover:text-white">×</button>
							</span>
						{/each}
						<input
							type="text"
							bind:value={tagInput}
							onkeydown={addTag}
							placeholder="Add tag..."
							class="w-24 bg-transparent text-xs text-white placeholder-gray-600 outline-none"
						/>
					</div>
				</div>

				<label class="flex items-center gap-2 text-xs text-gray-400">
					<input
						type="checkbox"
						checked={isPublic}
						onchange={(e) => onPublicChange((e.target as HTMLInputElement).checked)}
						class="h-4 w-4 rounded border-gray-600 bg-gray-800 text-blue-600"
					/>
					Public
				</label>
			</div>
		</div>
	{/if}
</div>
