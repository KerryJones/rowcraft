import type { PageServerLoad } from './$types';
import { createSupabaseServerClient } from '$lib/server/supabase';
import { normalizeWorkoutSegments } from '$lib/types';

export const load: PageServerLoad = async ({ cookies, url }) => {
	const supabase = createSupabaseServerClient(cookies);
	const {
		data: { session }
	} = await supabase.auth.getSession();

	const tab = url.searchParams.get('tab') ?? 'all';

	let query = supabase
		.from('workouts')
		.select('*')
		.order('created_at', { ascending: false })
		.limit(50);

	if (tab === 'mine' && session?.user) {
		query = query.eq('author_id', session.user.id);
	} else if (tab === 'community') {
		query = query.eq('is_public', true);
	} else {
		// "all" tab: public workouts + user's own
		if (session?.user) {
			query = query.or(`is_public.eq.true,author_id.eq.${session.user.id}`);
		} else {
			query = query.eq('is_public', true);
		}
	}

	const { data: workouts } = await query;

	// Normalize legacy segment formats (old {min,max} → {pace})
	const normalized = (workouts ?? []).map((w: any) => ({
		...w,
		segments: normalizeWorkoutSegments(w.segments ?? []),
	}));

	return {
		workouts: normalized,
		tab,
		userId: session?.user?.id ?? null
	};
};
