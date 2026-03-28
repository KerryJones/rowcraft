import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { C2_CLIENT_ID } from '$env/static/private';
import { createSupabaseServerClient } from '$lib/server/supabase';

export const GET: RequestHandler = async ({ url, cookies }) => {
	// Verify user is authenticated
	const supabase = createSupabaseServerClient(cookies);
	const { data: { user } } = await supabase.auth.getUser();
	if (!user) {
		redirect(303, '/auth/login');
	}

	// Generate CSRF state and store in cookie
	const state = crypto.randomUUID();
	cookies.set('c2_oauth_state', state, {
		path: '/',
		secure: true,
		httpOnly: true,
		sameSite: 'lax', // Must be lax (not strict) so the cookie is sent on the C2 redirect back
		maxAge: 600
	});

	// Redirect to C2 OAuth
	const authUrl = new URL('https://log.concept2.com/oauth/authorize');
	authUrl.searchParams.set('client_id', C2_CLIENT_ID);
	authUrl.searchParams.set('redirect_uri', `${url.origin}/c2/callback`);
	authUrl.searchParams.set('response_type', 'code');
	authUrl.searchParams.set('scope', 'user:read,results:write');
	authUrl.searchParams.set('state', state);

	redirect(302, authUrl.toString());
};
