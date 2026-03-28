import type { LayoutLoad } from './$types';
import type { CookieOptions } from '@supabase/ssr';
import { createBrowserClient, isBrowser, parse, serialize } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY } from '$env/static/public';

export const load: LayoutLoad = async ({ data, depends, fetch }) => {
	depends('supabase:auth');

	// On the server, just pass through the session from +layout.server.ts.
	// createBrowserClient uses document.cookie which doesn't exist during SSR.
	if (!isBrowser()) {
		return {
			supabase: null,
			session: data.session
		};
	}

	const supabase = createBrowserClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_PUBLISHABLE_KEY, {
		global: { fetch },
		cookies: {
			getAll() {
				const parsed = parse(document.cookie);
				return Object.entries(parsed).map(([name, value]) => ({ name, value }));
			},
			setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
				cookiesToSet.forEach(({ name, value, options }) => {
					document.cookie = serialize(name, value, options);
				});
			}
		},
		isBrowser: true
	});

	const {
		data: { session }
	} = await supabase.auth.getSession();

	return {
		supabase,
		session
	};
};
