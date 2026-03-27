import type { PageServerLoad } from './$types';
import { createSupabaseServerClient } from '$lib/server/supabase';

export const load: PageServerLoad = async ({ cookies, url }) => {
	const supabase = createSupabaseServerClient(cookies);
	const {
		data: { session }
	} = await supabase.auth.getSession();

	// Load all workouts for the workout picker
	const { data: workouts } = await supabase
		.from('workouts')
		.select('id, title')
		.order('title', { ascending: true });

	// If editing, load existing plan
	const editId = url.searchParams.get('edit');
	let plan = null;

	if (editId) {
		const { data: existingPlan } = await supabase
			.from('training_plans')
			.select('*')
			.eq('id', editId)
			.single();

		plan = existingPlan;
	}

	return {
		session,
		supabase,
		workouts: workouts ?? [],
		plan
	};
};
