import { writable } from 'svelte/store';
import type { Profile } from '$lib/types';
import type { User } from '@supabase/supabase-js';

interface AuthState {
	user: User | null;
	profile: Profile | null;
	loading: boolean;
}

function createAuthStore() {
	const { subscribe, set, update } = writable<AuthState>({
		user: null,
		profile: null,
		loading: true
	});

	return {
		subscribe,
		setUser(user: User | null) {
			update((state) => ({ ...state, user, loading: false }));
		},
		setProfile(profile: Profile | null) {
			update((state) => ({ ...state, profile }));
		},
		clear() {
			set({ user: null, profile: null, loading: false });
		},
		setLoading(loading: boolean) {
			update((state) => ({ ...state, loading }));
		}
	};
}

export const auth = createAuthStore();
