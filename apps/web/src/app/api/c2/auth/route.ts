import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { consumeOAuthHandoff } from '@/lib/oauth-handoff';
import { createSupabaseServer } from '@/lib/supabase/server';

export async function GET(request: NextRequest) {
  const source = request.nextUrl.searchParams.get('source');
  const handoff = request.nextUrl.searchParams.get('handoff');

  let userId: string;

  if (source === 'mobile' && handoff) {
    // Mobile: redeem the one-time handoff id minted by /api/c2/auth/start.
    // The browser URL never carries the Supabase access token.
    const handoffUserId = await consumeOAuthHandoff(handoff, 'c2');
    if (!handoffUserId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    userId = handoffUserId;
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
  cookieStore.set('c2_oauth_state', state, {
    httpOnly: true,
    secure: isProduction,
    sameSite: 'lax',
    maxAge: 600,
    path: '/',
  });

  if (source === 'mobile') {
    // Store source and user ID so the callback can identify the mobile user
    cookieStore.set('c2_oauth_source', 'mobile', {
      httpOnly: true,
      secure: isProduction,
      sameSite: 'lax',
      maxAge: 600,
      path: '/',
    });
    cookieStore.set('c2_oauth_user_id', userId, {
      httpOnly: true,
      secure: isProduction,
      sameSite: 'lax',
      maxAge: 600,
      path: '/',
    });
  }

  const authorizeUrl =
    `${process.env.C2_BASE_URL}/oauth/authorize` +
    `?client_id=${process.env.C2_CLIENT_ID}` +
    `&redirect_uri=${encodeURIComponent(process.env.C2_REDIRECT_URI!)}` +
    `&response_type=code` +
    `&scope=user:read,results:write` +
    `&state=${state}`;

  return NextResponse.redirect(authorizeUrl);
}
