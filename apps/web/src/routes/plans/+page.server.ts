import type { PageServerLoad } from './$types';
import { createSupabaseServerClient } from '$lib/server/supabase';

export const load: PageServerLoad = async ({ cookies }) => {
	const supabase = createSupabaseServerClient(cookies);
	const {
		data: { session }
	} = await supabase.auth.getSession();

	const { data: plans } = await supabase
		.from('training_plans')
		.select('*')
		.eq('is_active', true)
		.order('created_at', { ascending: false });

	return {
		plans: plans ?? [],
		userId: session?.user?.id ?? null
	};
};
