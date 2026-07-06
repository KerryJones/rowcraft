import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { createClient } from '@supabase/supabase-js';
import { createSupabaseServer } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const code = searchParams.get('code');
  const state = searchParams.get('state');

  const cookieStore = await cookies();
  const storedState = cookieStore.get('strava_oauth_state')?.value;
  const source = cookieStore.get('strava_oauth_source')?.value;
  const mobileUserId = cookieStore.get('strava_oauth_user_id')?.value;

  // Delete cookies regardless of outcome
  cookieStore.delete('strava_oauth_state');
  cookieStore.delete('strava_oauth_source');
  cookieStore.delete('strava_oauth_user_id');

  const isMobile = source === 'mobile';

  function errorRedirect(error: string) {
    if (isMobile) {
      return NextResponse.redirect(`com.rowcraft.app://login-callback?service=strava&error=${error}`);
    }
    return NextResponse.redirect(`${origin}/profile?error=${error}`);
  }

  function successRedirect() {
    if (isMobile) {
      return NextResponse.redirect('com.rowcraft.app://login-callback?service=strava&success=true');
    }
    return NextResponse.redirect(`${origin}/profile?strava=connected`);
  }

  if (!code || !state || state !== storedState) {
    return errorRedirect('strava_oauth_failed');
  }

  // Exchange code for tokens
  const tokenResponse = await fetch('https://www.strava.com/api/v3/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: process.env.STRAVA_CLIENT_ID,
      client_secret: process.env.STRAVA_CLIENT_SECRET,
      code,
      grant_type: 'authorization_code',
    }),
  });

  if (!tokenResponse.ok) {
    return errorRedirect('strava_token_exchange_failed');
  }

  const tokenData = await tokenResponse.json();
  const { access_token, refresh_token, expires_at, athlete } = tokenData;

  if (!athlete?.id) {
    return errorRedirect('strava_athlete_missing');
  }

  // Identify the app user — mobile uses stored user ID, web uses cookie session
  let appUserId: string;
  if (isMobile) {
    if (!mobileUserId) {
      return errorRedirect('strava_session_expired');
    }
    appUserId = mobileUserId;
  } else {
    const supabase = await createSupabaseServer();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return errorRedirect('strava_oauth_failed');
    }
    appUserId = user.id;
  }

  // Service role client — tokens live in the service-role-only
  // integration_tokens table, and mobile has no cookie session anyway.
  const supabaseAdmin = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  const { error: tokenError } = await supabaseAdmin
    .from('integration_tokens')
    .upsert(
      {
        user_id: appUserId,
        provider: 'strava',
        access_token,
        refresh_token: refresh_token ?? null,
        expires_at: expires_at ?? null,
      },
      { onConflict: 'user_id,provider' },
    );

  if (tokenError) {
    return errorRedirect('strava_save_failed');
  }

  const { error: updateError } = await supabaseAdmin
    .from('profiles')
    .update({ strava_athlete_id: String(athlete.id) })
    .eq('id', appUserId);

  if (updateError) {
    return errorRedirect('strava_save_failed');
  }

  return successRedirect();
}
