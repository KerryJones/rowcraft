import { NextRequest, NextResponse } from 'next/server';
import { createSupabaseServer } from '@/lib/supabase/server';
import { createClient } from '@supabase/supabase-js';

async function getAuthenticatedUserId(request: NextRequest): Promise<string | null> {
  const authHeader = request.headers.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    // Mobile: verify token directly against Supabase Auth
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    return user?.id ?? null;
  }
  // Web: cookie-based session
  const supabase = await createSupabaseServer();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id ?? null;
}

export async function POST(request: NextRequest) {
  const userId = await getAuthenticatedUserId(request);
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { result_id } = await request.json();

  if (!result_id) {
    return NextResponse.json({ error: 'result_id is required' }, { status: 400 });
  }

  // Use service role client for DB operations to bypass RLS
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  // Fetch the workout result
  const { data: result, error: resultError } = await supabase
    .from('workout_results')
    .select('*')
    .eq('id', result_id)
    .eq('user_id', userId)
    .single();

  if (resultError || !result) {
    return NextResponse.json({ error: 'Workout result not found' }, { status: 404 });
  }

  // Fetch user's C2 tokens
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('c2_access_token, c2_refresh_token, c2_user_id')
    .eq('id', userId)
    .single();

  if (profileError || !profile?.c2_access_token || !profile?.c2_user_id) {
    return NextResponse.json({ error: 'Not connected to C2' }, { status: 400 });
  }

  // Post result to C2 Logbook
  const c2Response = await fetch(
    `${process.env.C2_BASE_URL}/api/users/${profile.c2_user_id}/results`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${profile.c2_access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        type: 'rower',
        distance: result.total_distance,
        time: result.total_time,
      }),
    },
  );

  if (c2Response.status === 401) {
    return NextResponse.json(
      { error: 'C2 token expired, reconnect' },
      { status: 401 },
    );
  }

  if (!c2Response.ok) {
    return NextResponse.json(
      { error: 'Failed to sync to C2' },
      { status: 502 },
    );
  }

  // Mark as synced
  const { error: syncError } = await supabase
    .from('workout_results')
    .update({ synced_to_c2: true })
    .eq('id', result_id);

  if (syncError) {
    return NextResponse.json(
      { error: 'Synced to C2 but failed to update local record' },
      { status: 500 },
    );
  }

  return NextResponse.json({ success: true });
}
