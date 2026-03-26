import type { PageServerLoad } from './$types';
import { createSupabaseServerClient } from '$lib/server/supabase';
import { error } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ params, cookies }) => {
	const supabase = createSupabaseServerClient(cookies);
	const {
		data: { session }
	} = await supabase.auth.getSession();

	const { data: workout, error: fetchError } = await supabase
		.from('workouts')
		.select('*')
		.eq('id', params.id)
		.single();

	if (fetchError || !workout) {
		error(404, 'Workout not found');
	}

	// Check access: must be public or owned by user
	if (!workout.is_public && workout.author_id !== session?.user?.id) {
		error(403, 'You do not have access to this workout');
	}

	return {
		workout,
		userId: session?.user?.id ?? null,
		supabase
	};
};
