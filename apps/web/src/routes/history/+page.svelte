<script lang="ts">
	import MetricCard from '$lib/components/MetricCard.svelte';
	import { formatPace, formatTimeTenths, formatDistance } from '$lib/utils/format';

	let { data } = $props();

	let selectedResultId = $state<string | null>(null);

	const results = $derived(data.results);

	function toggleResult(id: string) {
		selectedResultId = selectedResultId === id ? null : id;
	}

	function formatDate(dateStr: string): string {
		return new Date(dateStr).toLocaleDateString('en-US', {
			weekday: 'short',
			month: 'short',
			day: 'numeric',
			year: 'numeric'
		});
	}

	function getWorkoutTitle(result: any): string {
		return result.workouts?.title ?? 'Free Row';
	}
</script>

<svelte:head>
	<title>History - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
	<h1 class="mb-8 text-2xl font-bold text-white">Workout History</h1>

	{#if results.length === 0}
		<!-- Empty state -->
		<div class="rounded-xl border border-gray-800 bg-gray-900 py-20 text-center">
			<svg class="mx-auto h-16 w-16 text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
			</svg>
			<h2 class="mt-4 text-lg font-semibold text-gray-400">No workouts yet</h2>
			<p class="mt-2 text-sm text-gray-500">
				Complete a workout on the mobile app and it will appear here.
			</p>
			<a
				href="/workouts"
				class="mt-6 inline-block rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-500"
			>
				Browse Workouts
			</a>
		</div>
	{:else}
		<div class="space-y-3">
			{#each results as result}
				<button
					onclick={() => toggleResult(result.id)}
					class="w-full rounded-xl border border-gray-800 bg-gray-900 p-4 text-left transition-colors hover:border-gray-700 {selectedResultId === result.id ? 'border-blue-500/50' : ''}"
				>
					<div class="flex items-center justify-between">
						<div>
							<p class="font-semibold text-white">{getWorkoutTitle(result)}</p>
							<p class="mt-1 text-sm text-gray-500">{formatDate(result.started_at)}</p>
						</div>
						<div class="flex items-center gap-6 text-right">
							{#if result.total_distance}
								<div>
									<p class="text-sm font-semibold text-white">{formatDistance(result.total_distance)}</p>
									<p class="text-xs text-gray-500">Distance</p>
								</div>
							{/if}
							{#if result.total_time}
								<div>
									<p class="text-sm font-semibold text-white">{formatTimeTenths(result.total_time)}</p>
									<p class="text-xs text-gray-500">Time</p>
								</div>
							{/if}
							{#if result.avg_split}
								<div>
									<p class="text-sm font-semibold text-white">{formatPace(result.avg_split)}</p>
									<p class="text-xs text-gray-500">Avg Split</p>
								</div>
							{/if}
						</div>
					</div>

					<!-- Expanded detail -->
					{#if selectedResultId === result.id}
						<div class="mt-4 border-t border-gray-800 pt-4">
							<div class="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
								<MetricCard label="Distance" value={result.total_distance ? formatDistance(result.total_distance) : '--'} />
								<MetricCard label="Time" value={result.total_time ? formatTimeTenths(result.total_time) : '--'} />
								<MetricCard label="Avg Pace" value={result.avg_split ? formatPace(result.avg_split) : '--'} unit="/500m" />
								<MetricCard label="Avg SPM" value={result.avg_stroke_rate ? String(result.avg_stroke_rate) : '--'} />
							</div>

							<div class="grid grid-cols-2 gap-3 sm:grid-cols-4 mb-3">
								<MetricCard label="Avg Watts" value={result.avg_watts ? String(result.avg_watts) : '--'} />
								<MetricCard label="Calories" value={result.calories ? String(result.calories) : '--'} />
								<MetricCard label="Avg HR" value={result.avg_heart_rate ? String(result.avg_heart_rate) : '--'} unit="bpm" />
								<MetricCard
									label="C2 Synced"
									value={result.synced_to_c2 ? 'Yes' : 'No'}
								/>
							</div>

							{#if result.splits?.length > 0}
								<h3 class="mb-2 text-sm font-medium text-gray-400">Splits</h3>
								<div class="overflow-x-auto">
									<table class="w-full text-sm">
										<thead>
											<tr class="text-left text-xs text-gray-500">
												<th class="pb-2 pr-4">#</th>
												<th class="pb-2 pr-4">Distance</th>
												<th class="pb-2 pr-4">Time</th>
												<th class="pb-2 pr-4">Pace</th>
												<th class="pb-2 pr-4">SPM</th>
												<th class="pb-2 pr-4">Watts</th>
												{#if result.splits.some((s: any) => s.avg_heart_rate)}
													<th class="pb-2">HR</th>
												{/if}
											</tr>
										</thead>
										<tbody>
											{#each result.splits as split, i}
												<tr class="border-t border-gray-800/50">
													<td class="py-1.5 pr-4 text-gray-500">{i + 1}</td>
													<td class="py-1.5 pr-4 text-white">{formatDistance(split.distance)}</td>
													<td class="py-1.5 pr-4 text-white">{formatTimeTenths(split.time)}</td>
													<td class="py-1.5 pr-4 font-mono text-white">{formatPace(split.avg_split)}</td>
													<td class="py-1.5 pr-4 text-white">{split.avg_stroke_rate}</td>
													<td class="py-1.5 pr-4 text-white">{split.avg_watts}</td>
													{#if result.splits.some((s: any) => s.avg_heart_rate)}
														<td class="py-1.5 text-white">{split.avg_heart_rate ?? '-'}</td>
													{/if}
												</tr>
											{/each}
										</tbody>
									</table>
								</div>
							{/if}
						</div>
					{/if}
				</button>
			{/each}
		</div>
	{/if}
</div>
