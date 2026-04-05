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

  // Fetch user's C2 tokens and weight
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('c2_access_token, c2_refresh_token, c2_user_id, weight_kg')
    .eq('id', userId)
    .single();

  if (profileError || !profile?.c2_access_token || !profile?.c2_user_id) {
    return NextResponse.json({ error: 'Not connected to C2' }, { status: 400 });
  }

  if (!result.finished_at) {
    return NextResponse.json({ error: 'Workout not finished' }, { status: 422 });
  }

  // Derive C2 weight class from profile weight (required for type=rower)
  if (profile.weight_kg == null) {
    return NextResponse.json(
      { error: 'Weight not set. Set your weight in Profile to sync to C2 Logbook.' },
      { status: 422 },
    );
  }
  const weightClass = profile.weight_kg < 75 ? 'L' : 'H';

  // Format finished_at as C2 date in UTC: yyyy-mm-dd hh:mm:ss
  const finishedAt = new Date(result.finished_at);
  const c2Date = [
    finishedAt.getUTCFullYear(),
    String(finishedAt.getUTCMonth() + 1).padStart(2, '0'),
    String(finishedAt.getUTCDate()).padStart(2, '0'),
  ].join('-') + ' ' + [
    String(finishedAt.getUTCHours()).padStart(2, '0'),
    String(finishedAt.getUTCMinutes()).padStart(2, '0'),
    String(finishedAt.getUTCSeconds()).padStart(2, '0'),
  ].join(':');

  // Build C2 API payload with required + optional fields.
  // Both DB and C2 API use tenths of seconds for time.
  const c2Payload: Record<string, unknown> = {
    type: 'rower',
    date: c2Date,
    distance: result.total_distance,
    time: result.total_time,
    weight_class: weightClass,
  };
  if (result.avg_stroke_rate != null) {
    c2Payload.stroke_rate = result.avg_stroke_rate;
  }
  if (result.calories != null) {
    c2Payload.calories_total = result.calories;
  }
  if (result.avg_heart_rate != null) {
    c2Payload.heart_rate = { average: result.avg_heart_rate };
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
      body: JSON.stringify(c2Payload),
    },
  );

  if (c2Response.status === 401 && profile.c2_refresh_token) {
    // Attempt to refresh the access token
    const refreshResponse = await fetch(`${process.env.C2_BASE_URL}/oauth/access_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: profile.c2_refresh_token,
        client_id: process.env.C2_CLIENT_ID!,
        client_secret: process.env.C2_CLIENT_SECRET!,
      }),
    });

    if (!refreshResponse.ok) {
      return NextResponse.json(
        { error: 'C2 token expired — reconnect in Profile' },
        { status: 401 },
      );
    }

    const refreshData = await refreshResponse.json();
    const newAccessToken: string | undefined = refreshData.access_token;
    const newRefreshToken: string | undefined = refreshData.refresh_token;

    if (!newAccessToken) {
      return NextResponse.json(
        { error: 'C2 token expired — reconnect in Profile' },
        { status: 401 },
      );
    }

    // Persist refreshed tokens (best-effort — proceed with sync even if this fails)
    await supabase
      .from('profiles')
      .update({
        c2_access_token: newAccessToken,
        ...(newRefreshToken ? { c2_refresh_token: newRefreshToken } : {}),
      })
      .eq('id', userId);

    // Retry the sync with the new token
    const retryResponse = await fetch(
      `${process.env.C2_BASE_URL}/api/users/${profile.c2_user_id}/results`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${newAccessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(c2Payload),
      },
    );

    if (!retryResponse.ok) {
      const body = await retryResponse.text().catch(() => '');
      return NextResponse.json(
        { error: `Failed to sync to C2 after token refresh: ${retryResponse.status}`, detail: body },
        { status: retryResponse.status === 401 ? 401 : retryResponse.status === 429 ? 429 : 502 },
      );
    }

    // Retry succeeded — fall through to mark as synced
  } else if (c2Response.status === 401) {
    return NextResponse.json(
      { error: 'C2 token expired — reconnect in Profile' },
      { status: 401 },
    );
  } else if (c2Response.status === 429) {
    return NextResponse.json(
      { error: 'C2 rate limit exceeded' },
      { status: 429 },
    );
  } else if (!c2Response.ok) {
    const body = await c2Response.text().catch(() => '');
    return NextResponse.json(
      { error: `Failed to sync to C2: ${c2Response.status}`, detail: body },
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
