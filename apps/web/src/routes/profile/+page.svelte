<script lang="ts">
	import { goto, invalidate } from '$app/navigation';

	let { data } = $props();

	let displayName = $state(data.session?.user?.user_metadata?.display_name ?? '');
	let saving = $state(false);
	let saveMessage = $state('');
	let connecting = $state(false);

	const email = $derived(data.session?.user?.email ?? '');

	// Check C2 link status from the profiles table
	let c2UserId = $state<string | null>(null);
	let profileLoaded = $state(false);

	$effect(() => {
		if (data.session?.user && !profileLoaded) {
			loadProfile();
		}
	});

	async function loadProfile() {
		const { data: profile } = await data.supabase
			.from('profiles')
			.select('c2_user_id, display_name')
			.eq('id', data.session.user.id)
			.single();

		if (profile) {
			c2UserId = profile.c2_user_id;
			if (profile.display_name && !displayName) {
				displayName = profile.display_name;
			}
		}
		profileLoaded = true;
	}

	async function updateProfile() {
		saving = true;
		saveMessage = '';

		try {
			// Update both auth metadata and profiles table
			const { error: authError } = await data.supabase.auth.updateUser({
				data: { display_name: displayName }
			});
			if (authError) throw authError;

			const { error: profileError } = await data.supabase
				.from('profiles')
				.update({ display_name: displayName })
				.eq('id', data.session.user.id);
			if (profileError) throw profileError;

			saveMessage = 'Profile updated successfully';
			setTimeout(() => { saveMessage = ''; }, 3000);
		} catch (err) {
			saveMessage = 'Failed to update profile';
		} finally {
			saving = false;
		}
	}

	async function signOut() {
		await data.supabase.auth.signOut();
		await invalidate('supabase:auth');
		goto('/');
	}

	async function connectC2Logbook() {
		connecting = true;
		try {
			// Generate a random state nonce — never use the access token as state
			const stateNonce = crypto.randomUUID();
			const supabaseUrl = data.supabase.supabaseUrl;

			// Redirect to the C2 Logbook OAuth edge function
			const authUrl = `${supabaseUrl}/functions/v1/c2-logbook-sync/auth?state=${stateNonce}`;
			window.location.href = authUrl;
		} catch (err) {
			console.error('Failed to start C2 OAuth:', err);
		} finally {
			connecting = false;
		}
	}

	async function disconnectC2Logbook() {
		try {
			const { error } = await data.supabase
				.from('profiles')
				.update({
					c2_user_id: null,
					c2_access_token: null,
					c2_refresh_token: null
				})
				.eq('id', data.session.user.id);

			if (!error) {
				c2UserId = null;
			}
		} catch (err) {
			console.error('Failed to disconnect C2 Logbook:', err);
		}
	}
</script>

<svelte:head>
	<title>Profile - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
	<h1 class="mb-8 text-2xl font-bold text-white">Profile</h1>

	<div class="space-y-8">
		<!-- Profile info -->
		<div class="rounded-xl border border-gray-800 bg-gray-900 p-6">
			<h2 class="mb-4 text-lg font-semibold text-white">Account</h2>

			<div class="space-y-4">
				<div>
					<label for="display-name" class="mb-1.5 block text-sm font-medium text-gray-300">
						Display Name
					</label>
					<input
						id="display-name"
						type="text"
						bind:value={displayName}
						class="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
					/>
				</div>

				<div>
					<label for="email" class="mb-1.5 block text-sm font-medium text-gray-300">Email</label>
					<input
						id="email"
						type="email"
						value={email}
						disabled
						class="w-full rounded-lg border border-gray-700 bg-gray-800/50 px-4 py-2.5 text-sm text-gray-400"
					/>
				</div>

				<div class="flex items-center justify-between">
					{#if saveMessage}
						<p class="text-sm {saveMessage.includes('success') ? 'text-emerald-400' : 'text-red-400'}">
							{saveMessage}
						</p>
					{:else}
						<div></div>
					{/if}
					<button
						onclick={updateProfile}
						disabled={saving}
						class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-blue-500 disabled:opacity-50"
					>
						{saving ? 'Saving...' : 'Save Changes'}
					</button>
				</div>
			</div>
		</div>

		<!-- C2 Logbook -->
		<div class="rounded-xl border border-gray-800 bg-gray-900 p-6">
			<h2 class="mb-4 text-lg font-semibold text-white">Concept2 Logbook</h2>
			<p class="mb-4 text-sm text-gray-400">
				Connect your Concept2 Logbook to automatically sync workout results.
			</p>

			{#if c2UserId}
				<div class="flex items-center justify-between">
					<div class="flex items-center gap-2">
						<div class="h-2 w-2 rounded-full bg-emerald-500"></div>
						<span class="text-sm font-medium text-emerald-400">Connected</span>
						<span class="text-xs text-gray-500">(ID: {c2UserId})</span>
					</div>
					<button
						onclick={disconnectC2Logbook}
						class="rounded-lg border border-red-500/30 px-4 py-2 text-sm font-medium text-red-400 transition-colors hover:bg-red-500/10"
					>
						Disconnect
					</button>
				</div>
			{:else}
				<button
					onclick={connectC2Logbook}
					disabled={connecting}
					class="rounded-lg border border-gray-700 bg-gray-800 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-gray-700 disabled:opacity-50"
				>
					{connecting ? 'Connecting...' : 'Connect Logbook'}
				</button>
			{/if}
		</div>

		<!-- Sign out -->
		<div class="border-t border-gray-800 pt-6">
			<button
				onclick={signOut}
				class="rounded-lg border border-gray-700 px-4 py-2 text-sm font-medium text-gray-400 transition-colors hover:border-gray-600 hover:text-white"
			>
				Sign Out
			</button>
		</div>
	</div>
</div>
