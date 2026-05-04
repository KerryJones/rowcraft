import { NextRequest, NextResponse } from 'next/server';
import { getAuthenticatedUserId } from '@/lib/supabase/server';
import { createClient } from '@supabase/supabase-js';
import {
  type TcxSegment,
  type TcxSplitJson,
  type TcxTimeSampleJson,
  buildTcx,
  buildStravaDescription,
} from '@/lib/utils/strava-tcx';

async function refreshStravaToken(
  refreshToken: string,
): Promise<{ access_token: string; refresh_token: string; expires_at: number } | null> {
  const response = await fetch('https://www.strava.com/api/v3/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: process.env.STRAVA_CLIENT_ID,
      client_secret: process.env.STRAVA_CLIENT_SECRET,
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    }),
  });

  if (!response.ok) return null;

  const data = await response.json();
  if (!data.access_token) return null;

  return {
    access_token: data.access_token,
    refresh_token: data.refresh_token ?? refreshToken,
    expires_at: data.expires_at,
  };
}

async function uploadToStrava(
  accessToken: string,
  tcxContent: string,
  name: string,
  description: string,
): Promise<{ ok: boolean; status: number; body: string }> {
  const formData = new FormData();
  formData.append('file', new Blob([tcxContent], { type: 'application/xml' }), 'workout.tcx');
  formData.append('data_type', 'tcx');
  formData.append('name', name);
  formData.append('sport_type', 'Rowing');
  formData.append('trainer', '1');
  formData.append('description', description);

  const response = await fetch('https://www.strava.com/api/v3/uploads', {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}` },
    body: formData,
  });

  const body = await response.text();
  return { ok: response.ok, status: response.status, body };
}

export async function POST(request: NextRequest) {
  const userId = await getAuthenticatedUserId(request);
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const body = await request.json();
  const { result_id } = body;

  if (!result_id) {
    return NextResponse.json({ error: 'result_id is required' }, { status: 400 });
  }

  // Use service role client for DB operations to bypass RLS
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  // Fetch the workout result with joined workout data
  const { data: result, error: resultError } = await supabase
    .from('workout_results')
    .select('*, workouts(title, workout_type, segments)')
    .eq('id', result_id)
    .eq('user_id', userId)
    .single();

  if (resultError || !result) {
    return NextResponse.json({ error: 'Workout result not found' }, { status: 404 });
  }

  // Fetch user's Strava tokens
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('strava_athlete_id, strava_access_token, strava_refresh_token, strava_token_expires_at')
    .eq('id', userId)
    .single();

  if (profileError || !profile?.strava_access_token || !profile?.strava_athlete_id) {
    return NextResponse.json({ error: 'Not connected to Strava' }, { status: 400 });
  }

  if (!result.finished_at) {
    return NextResponse.json({ error: 'Workout not finished' }, { status: 422 });
  }

  // Check if token needs refresh (expires_at is Unix timestamp in seconds)
  let accessToken = profile.strava_access_token as string;
  const expiresAt = profile.strava_token_expires_at as number | null;
  const nowUnix = Math.floor(Date.now() / 1000);

  if (expiresAt != null && expiresAt < nowUnix + 60) {
    // Token expired or expiring within 60s — refresh
    const refreshToken = profile.strava_refresh_token as string | null;
    if (!refreshToken) {
      return NextResponse.json(
        { error: 'Strava token expired — reconnect in Profile' },
        { status: 401 },
      );
    }

    const refreshed = await refreshStravaToken(refreshToken);
    if (!refreshed) {
      return NextResponse.json(
        { error: 'Strava token expired — reconnect in Profile' },
        { status: 401 },
      );
    }

    // Persist refreshed tokens (best-effort)
    await supabase
      .from('profiles')
      .update({
        strava_access_token: refreshed.access_token,
        strava_refresh_token: refreshed.refresh_token,
        strava_token_expires_at: refreshed.expires_at,
      })
      .eq('id', userId);

    accessToken = refreshed.access_token;
  }

  // Extract workout definition (may be null for free rows)
  const workout = result.workouts as { title: string; workout_type: string; segments: TcxSegment[] } | null;
  const splits: TcxSplitJson[] = result.splits ?? [];
  const timeSamples: TcxTimeSampleJson[] = result.time_samples ?? [];

  // Build TCX
  const tcxContent = buildTcx({
    started_at: result.started_at,
    finished_at: result.finished_at,
    total_distance: result.total_distance,
    total_time: result.total_time,
    avg_heart_rate: result.avg_heart_rate,
    max_heart_rate: result.max_heart_rate,
    avg_stroke_rate: result.avg_stroke_rate,
    calories: result.calories,
    splits,
    time_samples: timeSamples,
    segments: workout?.segments ?? [],
    workout_type: workout?.workout_type ?? null,
    workout_title: workout?.title,
  });

  // Build activity name and description
  const activityName = workout?.title ?? 'RowCraft Rowing';
  const description = buildStravaDescription({
    total_distance: result.total_distance,
    total_time: result.total_time,
    avg_stroke_rate: result.avg_stroke_rate,
    avg_split: result.avg_split,
  });

  // Upload to Strava
  const uploadResult = await uploadToStrava(accessToken, tcxContent, activityName, description);

  if (uploadResult.status === 401) {
    // Token rejected despite refresh check — ask user to reconnect
    return NextResponse.json(
      { error: 'Strava token expired — reconnect in Profile' },
      { status: 401 },
    );
  }

  if (uploadResult.status === 429) {
    return NextResponse.json(
      { error: 'Strava rate limit exceeded — try again later' },
      { status: 429 },
    );
  }

  if (!uploadResult.ok) {
    return NextResponse.json(
      { error: `Failed to upload to Strava: ${uploadResult.status}`, detail: uploadResult.body },
      { status: 502 },
    );
  }

  // Mark as synced — Strava processes the upload asynchronously, but the
  // file was accepted so we don't need to poll for completion.
  const { error: syncError } = await supabase
    .from('workout_results')
    .update({ synced_to_strava: true })
    .eq('id', result_id)
    .eq('user_id', userId);

  if (syncError) {
    return NextResponse.json(
      { error: 'Synced to Strava but failed to update local record' },
      { status: 500 },
    );
  }

  return NextResponse.json({ success: true });
}
