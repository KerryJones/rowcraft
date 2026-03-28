import type { PageServerLoad } from './$types';
import { createSupabaseServerClient } from '$lib/server/supabase';
import { error } from '@sveltejs/kit';
import { normalizeWorkoutSegments } from '$lib/types';

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

	// Normalize legacy segment formats
	workout.segments = normalizeWorkoutSegments(workout.segments ?? []);

	return {
		workout,
		userId: session?.user?.id ?? null
	};
};
