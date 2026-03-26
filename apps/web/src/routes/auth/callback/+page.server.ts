import type { PageServerLoad } from './$types';
import { redirect } from '@sveltejs/kit';
import { createSupabaseServerClient } from '$lib/server/supabase';

export const load: PageServerLoad = async ({ url, cookies }) => {
	const code = url.searchParams.get('code');

	if (code) {
		const supabase = createSupabaseServerClient(cookies);
		const { error } = await supabase.auth.exchangeCodeForSession(code);

		if (!error) {
			redirect(303, '/workouts');
		}
	}

	// If no code or error, redirect to login
	redirect(303, '/auth/login');
};
