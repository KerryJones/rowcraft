<script lang="ts">
	import { goto, invalidate } from '$app/navigation';
	import { page } from '$app/stores';
	import { PUBLIC_SUPABASE_URL } from '$env/static/public';
	import { formatPace, parsePace } from '$lib/utils/format';
	import { wattsToPaceTenths, paceTenthsToWatts, formatWatts, HR_ZONES, getHrZoneBpm } from '$lib/utils/ftp';

	let { data } = $props();

	// svelte-ignore state_referenced_locally
	let displayName = $state(data.session?.user?.user_metadata?.display_name ?? '');
	let saving = $state(false);
	let saveMessage = $state('');
	let connecting = $state(false);
	let c2Error = $state('');

	const email = $derived(data.session?.user?.email ?? '');

	// Check C2 link status from the profiles table
	let c2UserId = $state<string | null>(null);
	let profileLoaded = $state(false);

	// FTP and Max HR
	let ftpPaceInput = $state('');
	let ftpWatts = $state<number | null>(null);
	let maxHeartRate = $state<number | null>(null);

	const ftpWattsDisplay = $derived(ftpWatts ? formatWatts(ftpWatts) : null);
	const hrZonesDisplay = $derived.by(() => {
		if (!maxHeartRate) return [];
		return HR_ZONES.map((zone) => {
			const bpm = getHrZoneBpm(maxHeartRate!, zone.name);
			return { ...zone, bpmMin: bpm.min, bpmMax: bpm.max };
		});
	});

	function handleFtpPaceChange(e: Event) {
		const val = (e.target as HTMLInputElement).value;
		ftpPaceInput = val;
		const tenths = parsePace(val);
		if (tenths !== null) {
			ftpWatts = paceTenthsToWatts(tenths);
		}
	}

	$effect(() => {
		if (data.session?.user && !profileLoaded) {
			loadProfile();
		}
	});

	// Handle C2 OAuth error from server-side callback (once per page load)
	let errorHandled = false;
	$effect(() => {
		const error = $page.url.searchParams.get('error');
		if (error === 'c2_oauth_failed' && !errorHandled) {
			errorHandled = true;
			c2Error = 'Failed to connect Concept2 Logbook. Please try again.';
			// Clean the URL using SvelteKit's goto to keep $page store consistent
			const cleanUrl = new URL($page.url);
			cleanUrl.searchParams.delete('error');
			goto(cleanUrl.pathname + cleanUrl.search, { replaceState: true, noScroll: true });
		}
	});

	async function loadProfile() {
		if (!data.supabase || !data.session) return;
		const { data: profile } = await data.supabase
			.from('profiles')
			.select('c2_user_id, display_name, current_ftp_watts, max_heart_rate')
			.eq('id', data.session.user.id)
			.single();

		if (profile) {
			c2UserId = profile.c2_user_id;
			if (profile.display_name && !displayName) {
				displayName = profile.display_name;
			}
			if (profile.current_ftp_watts) {
				ftpWatts = profile.current_ftp_watts;
				ftpPaceInput = formatPace(wattsToPaceTenths(profile.current_ftp_watts));
			}
			if (profile.max_heart_rate) {
				maxHeartRate = profile.max_heart_rate;
			}
		}
		profileLoaded = true;
	}

	async function updateProfile() {
		if (!data.supabase || !data.session) return;
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
				.update({
					display_name: displayName,
					current_ftp_watts: ftpWatts,
					max_heart_rate: maxHeartRate,
				})
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
		if (!data.supabase) return;
		await data.supabase.auth.signOut();
		await invalidate('supabase:auth');
		goto('/');
	}

	function connectC2Logbook() {
		if (!data.session) return;
		connecting = true;
		c2Error = '';
		window.location.href = '/c2/auth';
	}

	async function disconnectC2Logbook() {
		if (!data.supabase || !data.session) return;
		c2Error = '';
		try {
			const { error } = await data.supabase
				.from('profiles')
				.update({
					c2_user_id: null,
					c2_access_token: null,
					c2_refresh_token: null
				})
				.eq('id', data.session.user.id);

			if (error) {
				c2Error = 'Failed to disconnect Concept2 Logbook. Please try again.';
			} else {
				c2UserId = null;
			}
		} catch (err) {
			console.error('Failed to disconnect C2 Logbook:', err);
			c2Error = 'Failed to disconnect Concept2 Logbook. Please try again.';
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

				<!-- FTP -->
				<div>
					<label for="ftp-pace" class="mb-1.5 block text-sm font-medium text-gray-300">
						FTP Pace
					</label>
					<div class="flex items-center gap-3">
						<input
							id="ftp-pace"
							type="text"
							value={ftpPaceInput}
							onchange={handleFtpPaceChange}
							placeholder="2:14"
							class="w-28 rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
						/>
						<span class="text-sm text-gray-500">/500m</span>
						{#if ftpWattsDisplay}
							<span class="text-sm text-gray-500">{ftpWattsDisplay}</span>
						{/if}
					</div>
					<p class="mt-1 text-xs text-gray-600">Your sustainable 60-minute pace</p>
				</div>

				<!-- Max Heart Rate -->
				<div>
					<label for="max-hr" class="mb-1.5 block text-sm font-medium text-gray-300">
						Max Heart Rate
					</label>
					<div class="flex items-center gap-3">
						<input
							id="max-hr"
							type="number"
							bind:value={maxHeartRate}
							placeholder="185"
							min="100"
							max="250"
							class="w-28 rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm text-white placeholder-gray-500 outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
						/>
						<span class="text-sm text-gray-500">bpm</span>
					</div>
					<p class="mt-1 text-xs text-gray-600">Usually 220 minus your age, or from a max effort test</p>
					{#if maxHeartRate && hrZonesDisplay.length > 0}
						<div class="mt-3 space-y-1">
							{#each hrZonesDisplay as zone}
								<div class="flex items-center gap-2 text-xs">
									<span class="w-24 font-medium text-gray-400">{zone.label}</span>
									<span class="font-mono text-gray-500">{zone.bpmMin}–{zone.bpmMax} bpm</span>
								</div>
							{/each}
						</div>
					{/if}
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

			{#if c2Error}
				<p class="mb-4 text-sm text-red-400">{c2Error}</p>
			{/if}

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
