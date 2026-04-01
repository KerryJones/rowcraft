import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { createClient } from '@supabase/supabase-js';
import { createSupabaseServer } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const code = searchParams.get('code');
  const state = searchParams.get('state');

  const cookieStore = await cookies();
  const storedState = cookieStore.get('c2_oauth_state')?.value;
  const source = cookieStore.get('c2_oauth_source')?.value;
  const mobileUserId = cookieStore.get('c2_oauth_user_id')?.value;

  // Delete cookies regardless of outcome
  cookieStore.delete('c2_oauth_state');
  cookieStore.delete('c2_oauth_source');
  cookieStore.delete('c2_oauth_user_id');

  const isMobile = source === 'mobile';

  function errorRedirect(error: string) {
    if (isMobile) {
      return NextResponse.redirect(`com.rowcraft.app://login-callback?error=${error}`);
    }
    return NextResponse.redirect(`${origin}/profile?error=${error}`);
  }

  function successRedirect() {
    if (isMobile) {
      return NextResponse.redirect('com.rowcraft.app://login-callback?success=true');
    }
    return NextResponse.redirect(`${origin}/profile?c2=connected`);
  }

  if (!code || !state || state !== storedState) {
    return errorRedirect('c2_oauth_failed');
  }

  // Exchange code for tokens
  const tokenResponse = await fetch(`${process.env.C2_BASE_URL}/oauth/access_token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: process.env.C2_REDIRECT_URI!,
      client_id: process.env.C2_CLIENT_ID!,
      client_secret: process.env.C2_CLIENT_SECRET!,
    }),
  });

  if (!tokenResponse.ok) {
    return errorRedirect('c2_token_exchange_failed');
  }

  const tokenData = await tokenResponse.json();
  const { access_token, refresh_token } = tokenData;

  // Fetch C2 user info
  const userResponse = await fetch(`${process.env.C2_BASE_URL}/api/users/me`, {
    headers: { Authorization: `Bearer ${access_token}` },
  });

  if (!userResponse.ok) {
    return errorRedirect('c2_user_fetch_failed');
  }

  const userData = await userResponse.json();
  if (!userData?.data?.id) {
    return errorRedirect('c2_user_fetch_failed');
  }
  const c2UserId = String(userData.data.id);

  // Identify the app user — mobile uses stored user ID, web uses cookie session
  let appUserId: string;
  if (isMobile) {
    if (!mobileUserId) {
      return errorRedirect('c2_session_expired');
    }
    appUserId = mobileUserId;
  } else {
    const supabase = await createSupabaseServer();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return errorRedirect('c2_oauth_failed');
    }
    appUserId = user.id;
  }

  // Store tokens using service role to bypass RLS
  const supabaseAdmin = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  const { error: updateError } = await supabaseAdmin
    .from('profiles')
    .update({
      c2_access_token: access_token,
      c2_refresh_token: refresh_token,
      c2_user_id: c2UserId,
    })
    .eq('id', appUserId);

  if (updateError) {
    return errorRedirect('c2_save_failed');
  }

  return successRedirect();
}
