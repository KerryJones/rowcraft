<script lang="ts">
	import { goto, invalidate } from '$app/navigation';
	import { page } from '$app/stores';
	import { PUBLIC_GOOGLE_CLIENT_ID } from '$env/static/public';

	let { data } = $props();

	let email = $state('');
	let password = $state('');
	let isSignUp = $state(false);
	let loading = $state(false);
	let error = $state($page.url.searchParams.get('error') === 'oauth_failed' ? 'Google sign-in failed. Please try again.' : '');
	let successMessage = $state('');

	async function handleSubmit(e: Event) {
		e.preventDefault();
		loading = true;
		error = '';

		try {
			if (isSignUp) {
				if (!data.supabase) return;
				const { error: signUpError } = await data.supabase.auth.signUp({
					email,
					password
				});
				if (signUpError) throw signUpError;
				// Show confirmation message inline
				error = '';
				isSignUp = false;
				successMessage = 'Account created! Check your email for a confirmation link.';
			} else {
				if (!data.supabase) return;
				const { error: signInError } = await data.supabase.auth.signInWithPassword({
					email,
					password
				});
				if (signInError) throw signInError;
				await invalidate('supabase:auth');
				goto('/workouts');
			}
		} catch (err: any) {
			error = err.message ?? 'An error occurred';
		} finally {
			loading = false;
		}
	}

	async function signInWithGoogle() {
		loading = true;
		error = '';

		try {
			const state = crypto.randomUUID();
			const rawNonce = crypto.randomUUID();

			// Store raw nonce in cookie — Supabase will hash it to verify against the JWT claim
			document.cookie = `google_oauth_state=${state}; path=/; SameSite=Lax; Secure; max-age=600`;
			document.cookie = `google_oauth_nonce=${rawNonce}; path=/; SameSite=Lax; Secure; max-age=600`;

			// Google stores SHA-256(nonce) in the id_token per OpenID Connect spec
			const encoded = new TextEncoder().encode(rawNonce);
			const hashBuffer = await crypto.subtle.digest('SHA-256', encoded);
			const hashedNonce = Array.from(new Uint8Array(hashBuffer))
				.map((b) => b.toString(16).padStart(2, '0'))
				.join('');

			const params = new URLSearchParams({
				client_id: PUBLIC_GOOGLE_CLIENT_ID,
				redirect_uri: `${window.location.origin}/auth/callback`,
				response_type: 'code',
				scope: 'openid email profile',
				state,
				nonce: hashedNonce
			});

			window.location.href = `https://accounts.google.com/o/oauth2/v2/auth?${params}`;
		} catch (err: any) {
			error = err.message ?? 'An error occurred';
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>{isSignUp ? 'Sign Up' : 'Log In'} - RowCraft</title>
</svelte:head>

<div class="flex min-h-[calc(100vh-8rem)] items-center justify-center px-4">
	<div class="w-full max-w-sm">
		<div class="mb-8 text-center">
			<h1 class="text-2xl font-bold text-white">
				{isSignUp ? 'Create your account' : 'Welcome back'}
			</h1>
			<p class="mt-2 text-sm text-gray-400">
				{isSignUp ? 'Start building structured rowing workouts' : 'Sign in to your RowCraft account'}
			</p>
		</div>

		<!-- Google OAuth -->
		<button
			onclick={signInWithGoogle}
			disabled={loading}
			class="flex w-full cursor-pointer items-center justify-center gap-3 rounded-lg border border-gray-700 bg-gray-900 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-gray-800 disabled:opacity-50"
		>
			<svg class="h-5 w-5" viewBox="0 0 24 24">
				<path
					fill="#4285F4"
					d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 01-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
				/>
				<path
					fill="#34A853"
					d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
				/>
				<path
					fill="#FBBC05"
					d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
				/>
				<path
					fill="#EA4335"
					d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
				/>
			</svg>
			Continue with Google
		</button>

		<div class="my-6 flex items-center gap-3">
			<div class="h-px flex-1 bg-gray-800"></div>
			<span class="text-xs text-gray-500">or</span>
			<div class="h-px flex-1 bg-gray-800"></div>
		</div>

		<!-- Email/password form -->
		<form onsubmit={handleSubmit} class="space-y-4">
			<div>
				<label for="email" class="mb-1.5 block text-sm font-medium text-gray-300">Email</label>
				<input
					id="email"
					type="email"
					bind:value={email}
					required
					class="w-full rounded-lg border border-gray-700 bg-gray-900 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
					placeholder="you@example.com"
				/>
			</div>

			<div>
				<label for="password" class="mb-1.5 block text-sm font-medium text-gray-300">Password</label>
				<input
					id="password"
					type="password"
					bind:value={password}
					required
					minlength="6"
					class="w-full rounded-lg border border-gray-700 bg-gray-900 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
					placeholder="At least 6 characters"
				/>
			</div>

			{#if successMessage}
				<div class="rounded-lg bg-emerald-500/10 p-3 text-sm text-emerald-400">
					{successMessage}
				</div>
			{/if}

			{#if error}
				<div class="rounded-lg bg-red-500/10 p-3 text-sm text-red-400">
					{error}
				</div>
			{/if}

			<button
				type="submit"
				disabled={loading}
				class="w-full rounded-lg bg-blue-600 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-500 disabled:opacity-50"
			>
				{#if loading}
					Loading...
				{:else}
					{isSignUp ? 'Create Account' : 'Sign In'}
				{/if}
			</button>
		</form>

		<p class="mt-6 text-center text-sm text-gray-400">
			{#if isSignUp}
				Already have an account?
				<button onclick={() => (isSignUp = false)} class="text-blue-500 hover:text-blue-400">
					Sign in
				</button>
			{:else}
				Don't have an account?
				<button onclick={() => (isSignUp = true)} class="text-blue-500 hover:text-blue-400">
					Sign up
				</button>
			{/if}
		</p>
	</div>
</div>
