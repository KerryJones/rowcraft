import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { createSupabaseServer } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const code = searchParams.get('code');
  const state = searchParams.get('state');

  const cookieStore = await cookies();
  const storedState = cookieStore.get('c2_oauth_state')?.value;

  // Delete the state cookie regardless of outcome
  cookieStore.delete('c2_oauth_state');

  if (!code || !state || state !== storedState) {
    return NextResponse.redirect(`${origin}/profile?error=c2_oauth_failed`);
  }

  // Exchange code for tokens
  const tokenResponse = await fetch('https://log.concept2.com/oauth/access_token', {
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
    return NextResponse.redirect(`${origin}/profile?error=c2_oauth_failed`);
  }

  const tokenData = await tokenResponse.json();
  const { access_token, refresh_token } = tokenData;

  // Fetch C2 user info
  const userResponse = await fetch('https://log.concept2.com/api/users/me', {
    headers: { Authorization: `Bearer ${access_token}` },
  });

  if (!userResponse.ok) {
    return NextResponse.redirect(`${origin}/profile?error=c2_oauth_failed`);
  }

  const userData = await userResponse.json();
  const c2UserId = String(userData.data.id);

  // Store tokens in user's profile
  const supabase = await createSupabaseServer();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.redirect(`${origin}/profile?error=c2_oauth_failed`);
  }

  const { error: updateError } = await supabase
    .from('profiles')
    .update({
      c2_access_token: access_token,
      c2_refresh_token: refresh_token,
      c2_user_id: c2UserId,
    })
    .eq('id', user.id);

  if (updateError) {
    return NextResponse.redirect(`${origin}/profile?error=c2_save_failed`);
  }

  return NextResponse.redirect(`${origin}/profile`);
}
