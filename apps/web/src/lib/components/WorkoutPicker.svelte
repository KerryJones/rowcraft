<script lang="ts">
	interface WorkoutOption {
		id: string;
		title: string;
	}

	interface Props {
		workouts: WorkoutOption[];
		value: string;
		onselect: (id: string) => void;
	}

	let { workouts, value, onselect }: Props = $props();

	let search = $state('');
	let open = $state(false);

	const filtered = $derived(() => {
		if (!search) return workouts;
		const q = search.toLowerCase();
		return workouts.filter((w) => w.title.toLowerCase().includes(q));
	});

	const selectedTitle = $derived(workouts.find((w) => w.id === value)?.title ?? '');

	function select(id: string) {
		onselect(id);
		open = false;
		search = '';
	}
</script>

<div class="relative">
	{#if !open}
		<button
			type="button"
			onclick={() => { open = true; }}
			class="w-full rounded-lg border border-gray-700 bg-gray-900 px-3 py-2 text-left text-sm transition-colors hover:border-gray-600 {value ? 'text-white' : 'text-gray-500'}"
		>
			{selectedTitle || 'Select workout...'}
		</button>
	{:else}
		<div class="rounded-lg border border-blue-500 bg-gray-900">
			<!-- svelte-ignore a11y_autofocus -->
			<input
				type="text"
				bind:value={search}
				placeholder="Search workouts..."
				onkeydown={(e) => { if (e.key === 'Escape') { open = false; search = ''; } }}
				class="w-full rounded-t-lg border-b border-gray-700 bg-gray-900 px-3 py-2 text-sm text-white placeholder-gray-500 outline-none"
				autofocus
			/>
			<div class="max-h-48 overflow-y-auto">
				{#each filtered() as workout}
					<button
						type="button"
						onclick={() => select(workout.id)}
						class="block w-full px-3 py-2 text-left text-sm transition-colors hover:bg-gray-800 {workout.id === value ? 'text-blue-400' : 'text-gray-300'}"
					>
						{workout.title}
					</button>
				{/each}
				{#if filtered().length === 0}
					<p class="px-3 py-2 text-sm text-gray-500">No workouts found</p>
				{/if}
			</div>
		</div>
		<button
			type="button"
			onclick={() => { open = false; search = ''; }}
			class="fixed inset-0 z-[-1]"
			tabindex="-1"
			aria-hidden="true"
		></button>
	{/if}
</div>
