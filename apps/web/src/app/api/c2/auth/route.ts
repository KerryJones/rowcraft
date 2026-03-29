import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { createSupabaseServer } from '@/lib/supabase/server';

export async function GET() {
  const supabase = await createSupabaseServer();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const state = crypto.randomUUID();

  const cookieStore = await cookies();
  cookieStore.set('c2_oauth_state', state, {
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 600,
    path: '/',
  });

  const authorizeUrl =
    `https://log.concept2.com/oauth/authorize` +
    `?client_id=${process.env.C2_CLIENT_ID}` +
    `&redirect_uri=${encodeURIComponent(process.env.C2_REDIRECT_URI!)}` +
    `&response_type=code` +
    `&scope=user:read,results:write` +
    `&state=${state}`;

  return NextResponse.redirect(authorizeUrl);
}
