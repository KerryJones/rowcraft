import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { createSupabaseServer } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const origin = new URL(request.url).origin;

  const loginUrl = new URL('/auth/login?error=oauth_failed', origin);

  const code = searchParams.get('code');
  const state = searchParams.get('state');
  const error = searchParams.get('error');

  // Read and immediately clear replay cookies regardless of outcome
  const cookieStore = await cookies();
  const savedState = cookieStore.get('google_oauth_state')?.value;
  const savedNonce = cookieStore.get('google_oauth_nonce')?.value;
  cookieStore.delete('google_oauth_state');
  cookieStore.delete('google_oauth_nonce');

  if (error) {
    console.error('Google OAuth error:', error);
    return NextResponse.redirect(loginUrl);
  }

  if (!code || !state || !savedState || !savedNonce || state !== savedState) {
    return NextResponse.redirect(loginUrl);
  }

  // Exchange authorization code for tokens with Google
  let tokenResponse: Response;
  try {
    tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      signal: AbortSignal.timeout(8000),
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id: process.env.GOOGLE_CLIENT_ID!,
        client_secret: process.env.GOOGLE_CLIENT_SECRET!,
        redirect_uri: `${origin}/auth/callback`,
        grant_type: 'authorization_code',
      }),
    });
  } catch (err) {
    console.error('Google token exchange error:', err);
    return NextResponse.redirect(loginUrl);
  }

  if (!tokenResponse.ok) {
    const body = await tokenResponse.text().catch(() => '(unreadable)');
    console.error('Google token exchange failed:', tokenResponse.status, body);
    return NextResponse.redirect(loginUrl);
  }

  let idToken: string | undefined;
  let accessToken: string | undefined;
  try {
    const tokens = await tokenResponse.json();
    idToken = typeof tokens.id_token === 'string' ? tokens.id_token : undefined;
    accessToken = typeof tokens.access_token === 'string' ? tokens.access_token : undefined;
  } catch (err) {
    console.error('Google token response parse error:', err);
    return NextResponse.redirect(loginUrl);
  }

  if (!idToken) {
    console.error('Google token response missing id_token');
    return NextResponse.redirect(loginUrl);
  }

  // Sign in to Supabase with the Google ID token
  try {
    const supabase = await createSupabaseServer();
    const { error: authError } = await supabase.auth.signInWithIdToken({
      provider: 'google',
      token: idToken,
      access_token: accessToken,
      nonce: savedNonce,
    });

    if (authError) {
      console.error('Supabase signInWithIdToken failed:', authError.message);
      return NextResponse.redirect(loginUrl);
    }
  } catch (err) {
    console.error('Supabase auth error:', err);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.redirect(new URL('/workouts', origin));
}
