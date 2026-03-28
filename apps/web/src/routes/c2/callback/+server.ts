import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { C2_CLIENT_ID, C2_CLIENT_SECRET } from '$env/static/private';
import { createSupabaseServerClient } from '$lib/server/supabase';

export const GET: RequestHandler = async ({ url, cookies }) => {
	const code = url.searchParams.get('code');
	const state = url.searchParams.get('state');
	const savedState = cookies.get('c2_oauth_state');

	// Delete cookie before validation to prevent replay
	cookies.delete('c2_oauth_state', { path: '/' });

	if (!code || !state || !savedState || state !== savedState) {
		redirect(303, '/profile?error=c2_oauth_failed');
	}

	// Verify user session
	const supabase = createSupabaseServerClient(cookies);
	const { data: { user } } = await supabase.auth.getUser();
	if (!user) {
		redirect(303, '/auth/login');
	}

	// Exchange code for tokens
	const tokenResponse = await fetch('https://log.concept2.com/oauth/access_token', {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: new URLSearchParams({
			grant_type: 'authorization_code',
			code,
			client_id: C2_CLIENT_ID,
			client_secret: C2_CLIENT_SECRET,
			redirect_uri: `${url.origin}/c2/callback`
		})
	});

	if (!tokenResponse.ok) {
		console.error('C2 token exchange failed:', tokenResponse.status);
		redirect(303, '/profile?error=c2_oauth_failed');
	}

	const tokens = await tokenResponse.json();

	// Fetch C2 user info
	const userResponse = await fetch('https://log.concept2.com/api/users/me', {
		headers: { Authorization: `Bearer ${tokens.access_token}` }
	});

	if (!userResponse.ok) {
		console.error('C2 user info fetch failed:', userResponse.status);
		redirect(303, '/profile?error=c2_oauth_failed');
	}

	const c2User = await userResponse.json();
	if (!c2User?.data?.id) {
		console.error('Invalid C2 user response:', c2User);
		redirect(303, '/profile?error=c2_oauth_failed');
	}

	// Store tokens in profiles table (RLS allows auth.uid() = id)
	const { error } = await supabase
		.from('profiles')
		.update({
			c2_user_id: String(c2User.data.id),
			c2_access_token: tokens.access_token,
			c2_refresh_token: tokens.refresh_token
		})
		.eq('id', user.id);

	if (error) {
		console.error('Failed to store C2 tokens:', error.message);
		redirect(303, '/profile?error=c2_oauth_failed');
	}

	redirect(303, '/profile');
};
