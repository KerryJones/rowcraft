<script lang="ts">
	import { goto } from '$app/navigation';

	let { data } = $props();

	const isLoggedIn = $derived(!!data.session?.user);

	$effect(() => {
		if (isLoggedIn) {
			goto('/workouts');
		}
	});
</script>

<svelte:head>
	<title>RowCraft - Structured Rowing Workouts</title>
</svelte:head>

{#if !isLoggedIn}
	<div class="flex flex-col">
		<!-- Hero -->
		<section class="relative overflow-hidden">
			<div class="absolute inset-0 bg-gradient-to-br from-blue-900/20 via-gray-950 to-gray-950"></div>
			<div class="relative mx-auto max-w-7xl px-4 py-24 sm:px-6 sm:py-32 lg:px-8 lg:py-40">
				<div class="mx-auto max-w-3xl text-center">
					<h1 class="text-4xl font-bold tracking-tight text-white sm:text-5xl lg:text-6xl">
						Structured Rowing
						<span class="text-blue-500">Workouts</span>
					</h1>
					<p class="mt-6 text-lg leading-8 text-gray-400 sm:text-xl">
						Build custom intervals, connect your Concept2 PM5, and track every stroke.
						Share your best workouts with the rowing community.
					</p>
					<div class="mt-10 flex items-center justify-center gap-4">
						<a
							href="/auth/login"
							class="rounded-lg bg-blue-600 px-6 py-3 text-sm font-semibold text-white shadow-lg transition-colors hover:bg-blue-500"
						>
							Get Started Free
						</a>
						<a
							href="/workouts"
							class="rounded-lg border border-gray-700 px-6 py-3 text-sm font-semibold text-gray-300 transition-colors hover:border-gray-600 hover:text-white"
						>
							Browse Workouts
						</a>
					</div>
				</div>
			</div>
		</section>

		<!-- Features grid -->
		<section class="mx-auto max-w-7xl px-4 py-20 sm:px-6 lg:px-8">
			<div class="mx-auto max-w-2xl text-center">
				<h2 class="text-3xl font-bold text-white">Everything you need to row better</h2>
				<p class="mt-4 text-gray-400">
					From building workouts to analyzing your splits, RowCraft has you covered.
				</p>
			</div>

			<div class="mt-16 grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
				<!-- Build workouts -->
				<div class="rounded-xl border border-gray-800 bg-gray-900 p-6">
					<div class="flex h-12 w-12 items-center justify-center rounded-lg bg-blue-500/10">
						<svg class="h-6 w-6 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
						</svg>
					</div>
					<h3 class="mt-4 text-lg font-semibold text-white">Build Workouts</h3>
					<p class="mt-2 text-sm leading-6 text-gray-400">
						Create custom intervals with work, rest, warmup, and cooldown segments. Set pace and stroke rate targets.
					</p>
				</div>

				<!-- Connect PM5 -->
				<div class="rounded-xl border border-gray-800 bg-gray-900 p-6">
					<div class="flex h-12 w-12 items-center justify-center rounded-lg bg-emerald-500/10">
						<svg class="h-6 w-6 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
						</svg>
					</div>
					<h3 class="mt-4 text-lg font-semibold text-white">Connect PM5</h3>
					<p class="mt-2 text-sm leading-6 text-gray-400">
						Pair with your Concept2 PM5 via Bluetooth. Real-time metrics stream directly to the app.
					</p>
				</div>

				<!-- Track progress -->
				<div class="rounded-xl border border-gray-800 bg-gray-900 p-6">
					<div class="flex h-12 w-12 items-center justify-center rounded-lg bg-amber-500/10">
						<svg class="h-6 w-6 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
						</svg>
					</div>
					<h3 class="mt-4 text-lg font-semibold text-white">Track Progress</h3>
					<p class="mt-2 text-sm leading-6 text-gray-400">
						Review every workout with detailed split data. See your improvement over time with pace and distance trends.
					</p>
				</div>

				<!-- Share -->
				<div class="rounded-xl border border-gray-800 bg-gray-900 p-6">
					<div class="flex h-12 w-12 items-center justify-center rounded-lg bg-purple-500/10">
						<svg class="h-6 w-6 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
						</svg>
					</div>
					<h3 class="mt-4 text-lg font-semibold text-white">Share with Community</h3>
					<p class="mt-2 text-sm leading-6 text-gray-400">
						Publish your best workouts for others to discover. Fork and customize workouts from the community library.
					</p>
				</div>
			</div>
		</section>

		<!-- CTA -->
		<section class="border-t border-gray-800 bg-gray-900/50">
			<div class="mx-auto max-w-7xl px-4 py-16 text-center sm:px-6 lg:px-8">
				<h2 class="text-2xl font-bold text-white">Ready to row?</h2>
				<p class="mt-4 text-gray-400">Join the RowCraft community and start building better workouts today.</p>
				<a
					href="/auth/login"
					class="mt-8 inline-block rounded-lg bg-blue-600 px-8 py-3 text-sm font-semibold text-white shadow-lg transition-colors hover:bg-blue-500"
				>
					Get Started Free
				</a>
			</div>
		</section>
	</div>
{/if}
