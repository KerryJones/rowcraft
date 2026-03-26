<script lang="ts">
	import '../app.css';
	import { goto, invalidate } from '$app/navigation';
	import { page } from '$app/stores';

	let { data, children } = $props();

	let mobileMenuOpen = $state(false);

	const session = $derived(data.session);
	const isLoggedIn = $derived(!!session?.user);

	const navLinks = $derived(
		isLoggedIn
			? [
					{ href: '/workouts', label: 'Workouts' },
					{ href: '/builder', label: 'Builder' },
					{ href: '/history', label: 'History' },
					{ href: '/profile', label: 'Profile' }
				]
			: [
					{ href: '/workouts', label: 'Workouts' },
					{ href: '/auth/login', label: 'Login' }
				]
	);

	function isActive(href: string): boolean {
		return $page.url.pathname === href || $page.url.pathname.startsWith(href + '/');
	}

	function toggleMobileMenu() {
		mobileMenuOpen = !mobileMenuOpen;
	}

	function closeMobileMenu() {
		mobileMenuOpen = false;
	}
</script>

<div class="flex min-h-screen flex-col">
	<!-- Navigation -->
	<nav class="sticky top-0 z-50 border-b border-gray-800 bg-gray-950/95 backdrop-blur-sm">
		<div class="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
			<!-- Logo -->
			<a href="/" class="flex items-center gap-2 text-xl font-bold text-white">
				<svg class="h-8 w-8 text-blue-500" viewBox="0 0 32 32" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M4 16h24M8 10l4 6-4 6M20 10l4 6-4 6" />
				</svg>
				RowCraft
			</a>

			<!-- Desktop nav -->
			<div class="hidden items-center gap-1 md:flex">
				{#each navLinks as link}
					<a
						href={link.href}
						class="rounded-lg px-3 py-2 text-sm font-medium transition-colors {isActive(link.href)
							? 'bg-gray-800 text-white'
							: 'text-gray-400 hover:bg-gray-800/50 hover:text-white'}"
					>
						{link.label}
					</a>
				{/each}
			</div>

			<!-- Mobile hamburger -->
			<button
				class="rounded-lg p-2 text-gray-400 hover:bg-gray-800 hover:text-white md:hidden"
				onclick={toggleMobileMenu}
				aria-label="Toggle menu"
			>
				<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					{#if mobileMenuOpen}
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
					{:else}
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
					{/if}
				</svg>
			</button>
		</div>

		<!-- Mobile menu -->
		{#if mobileMenuOpen}
			<div class="border-t border-gray-800 bg-gray-950 md:hidden">
				<div class="space-y-1 px-4 py-3">
					{#each navLinks as link}
						<a
							href={link.href}
							onclick={closeMobileMenu}
							class="block rounded-lg px-3 py-2 text-sm font-medium transition-colors {isActive(link.href)
								? 'bg-gray-800 text-white'
								: 'text-gray-400 hover:bg-gray-800/50 hover:text-white'}"
						>
							{link.label}
						</a>
					{/each}
				</div>
			</div>
		{/if}
	</nav>

	<!-- Main content -->
	<main class="flex-1">
		{@render children()}
	</main>

	<!-- Footer -->
	<footer class="border-t border-gray-800 py-8">
		<div class="mx-auto max-w-7xl px-4 text-center text-sm text-gray-500 sm:px-6 lg:px-8">
			RowCraft &mdash; Structured rowing workouts for Concept2 ergometers.
		</div>
	</footer>
</div>
