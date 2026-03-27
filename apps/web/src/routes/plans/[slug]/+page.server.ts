import type { PageServerLoad } from './$types';
import { createSupabaseServerClient } from '$lib/server/supabase';
import { error } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ params, cookies }) => {
	const supabase = createSupabaseServerClient(cookies);
	const {
		data: { session }
	} = await supabase.auth.getSession();

	const { data: plan, error: fetchError } = await supabase
		.from('training_plans')
		.select('*')
		.eq('slug', params.slug)
		.single();

	if (fetchError || !plan) {
		error(404, 'Plan not found');
	}

	// Collect all workout IDs referenced in the plan
	const workoutIds = new Set<string>();
	for (const week of plan.weeks ?? []) {
		for (const session of week.sessions ?? []) {
			if (session.workout_id) {
				workoutIds.add(session.workout_id);
			}
		}
	}

	// Fetch referenced workouts for title display
	let workoutMap: Record<string, string> = {};
	if (workoutIds.size > 0) {
		const { data: workouts } = await supabase
			.from('workouts')
			.select('id, title')
			.in('id', Array.from(workoutIds));

		if (workouts) {
			workoutMap = Object.fromEntries(workouts.map((w) => [w.id, w.title]));
		}
	}

	return {
		plan,
		workoutMap,
		userId: session?.user?.id ?? null
	};
};
