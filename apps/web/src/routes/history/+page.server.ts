import type { PageServerLoad } from './$types';
import { createSupabaseServerClient } from '$lib/server/supabase';
import { redirect } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ cookies }) => {
	const supabase = createSupabaseServerClient(cookies);
	const {
		data: { session }
	} = await supabase.auth.getSession();

	if (!session?.user) {
		redirect(303, '/auth/login');
	}

	// Join with workouts to get the title
	const { data: results } = await supabase
		.from('workout_results')
		.select('*, workouts(title)')
		.eq('user_id', session.user.id)
		.order('started_at', { ascending: false })
		.limit(50);

	return {
		results: results ?? []
	};
};
