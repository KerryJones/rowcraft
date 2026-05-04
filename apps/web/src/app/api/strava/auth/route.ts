import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { createClient } from '@supabase/supabase-js';
import { createSupabaseServer } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
  const source = request.nextUrl.searchParams.get('source');
  const token = request.nextUrl.searchParams.get('token');

  let userId: string;

  if (source === 'mobile' && token) {
    // Mobile: verify the Supabase access token passed as a query param
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    userId = user.id;
  } else {
    // Web: use cookie-based session
    const supabase = await createSupabaseServer();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    userId = user.id;
  }

  const state = crypto.randomUUID();
  const isProduction = process.env.NODE_ENV === 'production';

  const cookieStore = await cookies();
  cookieStore.set('strava_oauth_state', state, {
    httpOnly: true,
    secure: isProduction,
    sameSite: 'lax',
    maxAge: 600,
    path: '/',
  });

  if (source === 'mobile') {
    // Store source and user ID so the callback can identify the mobile user
    cookieStore.set('strava_oauth_source', 'mobile', {
      httpOnly: true,
      secure: isProduction,
      sameSite: 'lax',
      maxAge: 600,
      path: '/',
    });
    cookieStore.set('strava_oauth_user_id', userId, {
      httpOnly: true,
      secure: isProduction,
      sameSite: 'lax',
      maxAge: 600,
      path: '/',
    });
  }

  const authorizeUrl =
    `https://www.strava.com/oauth/authorize` +
    `?client_id=${process.env.STRAVA_CLIENT_ID}` +
    `&redirect_uri=${encodeURIComponent(process.env.STRAVA_REDIRECT_URI!)}` +
    `&response_type=code` +
    `&scope=activity:write` +
    `&state=${state}`;

  return NextResponse.redirect(authorizeUrl);
}
