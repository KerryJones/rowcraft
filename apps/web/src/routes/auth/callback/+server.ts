import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { PUBLIC_GOOGLE_CLIENT_ID } from '$env/static/public';
import { GOOGLE_CLIENT_SECRET } from '$env/static/private';
import { createSupabaseServerClient } from '$lib/server/supabase';

export const GET: RequestHandler = async ({ url, cookies }) => {
	const code = url.searchParams.get('code');
	const state = url.searchParams.get('state');
	const savedState = cookies.get('google_oauth_state');
	const savedNonce = cookies.get('google_oauth_nonce');

	// Delete cookies before validation to prevent replay
	cookies.delete('google_oauth_state', { path: '/' });
	cookies.delete('google_oauth_nonce', { path: '/' });

	if (!code || !state || !savedNonce || state !== savedState) {
		redirect(303, '/auth/login?error=oauth_failed');
	}

	// Exchange authorization code for tokens with Google
	const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: new URLSearchParams({
			code,
			client_id: PUBLIC_GOOGLE_CLIENT_ID,
			client_secret: GOOGLE_CLIENT_SECRET,
			redirect_uri: `${url.origin}/auth/callback`,
			grant_type: 'authorization_code'
		})
	});

	if (!tokenResponse.ok) {
		const body = await tokenResponse.text();
		console.error('Google token exchange failed:', tokenResponse.status, body);
		redirect(303, '/auth/login?error=oauth_failed');
	}

	const tokens = await tokenResponse.json();
	const idToken = tokens.id_token;
	const accessToken = tokens.access_token;

	if (!idToken) {
		console.error('Google token response missing id_token');
		redirect(303, '/auth/login?error=oauth_failed');
	}

	// Sign in to Supabase with the Google ID token
	const supabase = createSupabaseServerClient(cookies);
	const { error } = await supabase.auth.signInWithIdToken({
		provider: 'google',
		token: idToken,
		accessToken,
		nonce: savedNonce
	});

	if (error) {
		console.error('Supabase signInWithIdToken failed:', error.message);
		redirect(303, '/auth/login?error=oauth_failed');
	}

	redirect(303, '/workouts');
};
