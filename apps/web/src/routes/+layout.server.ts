import type { LayoutServerLoad } from './$types';
import { createSupabaseServerClient } from '$lib/server/supabase';

export const load: LayoutServerLoad = async ({ cookies }) => {
	const supabase = createSupabaseServerClient(cookies);
	const {
		data: { session }
	} = await supabase.auth.getSession();

	return {
		session
	};
};
