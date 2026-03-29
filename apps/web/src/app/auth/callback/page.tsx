import { redirect } from 'next/navigation';
import { cookies } from 'next/headers';
import { createSupabaseServer } from '@/lib/supabase/server';

interface PageProps {
  searchParams: Promise<{ code?: string; state?: string; error?: string }>;
}

export default async function AuthCallbackPage({ searchParams }: PageProps) {
  const params = await searchParams;

  // Handle OAuth error from Google
  if (params.error) {
    redirect('/auth/login?error=oauth_failed');
  }

  const code = params.code;
  const state = params.state;

  if (!code || !state) {
    redirect('/auth/login?error=oauth_failed');
  }

  const cookieStore = await cookies();
  const savedState = cookieStore.get('google_oauth_state')?.value;
  const savedNonce = cookieStore.get('google_oauth_nonce')?.value;

  // Delete cookies before validation to prevent replay
  cookieStore.delete('google_oauth_state');
  cookieStore.delete('google_oauth_nonce');

  if (!savedNonce || state !== savedState) {
    redirect('/auth/login?error=oauth_failed');
  }

  // Exchange authorization code for tokens with Google
  const origin = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID!,
      client_secret: process.env.GOOGLE_CLIENT_SECRET!,
      redirect_uri: `${origin}/auth/callback`,
      grant_type: 'authorization_code',
    }),
  });

  if (!tokenResponse.ok) {
    console.error('Google token exchange failed:', tokenResponse.status);
    redirect('/auth/login?error=oauth_failed');
  }

  const tokens = await tokenResponse.json();
  const idToken = tokens.id_token;
  const accessToken = tokens.access_token;

  if (!idToken) {
    console.error('Google token response missing id_token');
    redirect('/auth/login?error=oauth_failed');
  }

  // Sign in to Supabase with the Google ID token
  const supabase = await createSupabaseServer();
  const { error } = await supabase.auth.signInWithIdToken({
    provider: 'google',
    token: idToken,
    access_token: accessToken,
    nonce: savedNonce,
  });

  if (error) {
    console.error('Supabase signInWithIdToken failed:', error.message);
    redirect('/auth/login?error=oauth_failed');
  }

  redirect('/workouts');
}
