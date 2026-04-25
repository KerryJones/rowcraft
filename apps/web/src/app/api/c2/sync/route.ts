import { NextRequest, NextResponse } from 'next/server';
import truncate from 'lodash.truncate';
import { createSupabaseServer } from '@/lib/supabase/server';
import { createClient } from '@supabase/supabase-js';
import {
  type RowCraftWorkoutType,
  type C2Segment,
  type SplitJson,
  type TimeSampleJson,
  mapC2WorkoutType,
  buildHeartRateObject,
  buildSplits,
  buildIntervals,
  buildStrokeData,
  buildIntervalStrokeData,
} from '@/lib/utils/c2-payload';

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

  const body = await request.json();
  const { result_id, client_version, device, device_os, device_os_version } = body;

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

  // Extract workout definition (may be null for free rows)
  const workout = result.workouts as { title: string; workout_type: string; segments: C2Segment[] } | null;
  const workoutType = (workout?.workout_type ?? null) as RowCraftWorkoutType | null;
  const segments: C2Segment[] = workout?.segments ?? [];

  // Build C2 API payload
  const c2Payload: Record<string, unknown> = {
    type: 'rower',
    date: c2Date,
    distance: result.total_distance,
    time: result.total_time,
    weight_class: weightClass,
    workout_type: mapC2WorkoutType(workoutType, segments),
  };

  // Timezone (IANA format)
  if (result.timezone && result.timezone !== 'UTC') {
    c2Payload.timezone = result.timezone;
  }

  // Overall averages
  if (result.avg_stroke_rate != null) {
    c2Payload.stroke_rate = result.avg_stroke_rate;
  }
  if (result.calories != null) {
    c2Payload.calories_total = result.calories;
  }
  if (result.stroke_count > 0) {
    c2Payload.stroke_count = result.stroke_count;
  }
  if (result.drag_factor != null) {
    c2Payload.drag_factor = result.drag_factor;
  }

  // Compute watt-minutes
  if (result.avg_watts > 0 && result.total_time > 0) {
    const timeMinutes = result.total_time / 600;
    c2Payload.wattminutes_total = Math.round(result.avg_watts * timeMinutes);
  }

  // Heart rate
  const hr = buildHeartRateObject(
    result.avg_heart_rate,
    result.min_heart_rate,
    result.max_heart_rate,
    result.ending_heart_rate,
  );
  if (hr) c2Payload.heart_rate = hr;

  // Comments
  const workoutTitle = workout?.title;
  c2Payload.comments = workoutTitle
    ? truncate(`Rowed on RowCraft: ${workoutTitle}`, { length: 240, omission: '…' })
    : 'Rowed on RowCraft';

  // Splits, Intervals, and Stroke data
  const splits: SplitJson[] = result.splits ?? [];
  const timeSamples: TimeSampleJson[] = result.time_samples ?? [];
  const isInterval = (workoutType === 'intervals' || workoutType === 'variable_intervals')
    && segments.length > 0;

  // C2 API nests splits/intervals inside a "workout" object
  if (splits.length > 0) {
    if (isInterval) {
      const { intervals, totalRestTime, totalRestDistance } = buildIntervals(splits, segments);
      if (intervals.length > 0) {
        c2Payload.workout = { intervals };
      }
      if (totalRestTime > 0) c2Payload.rest_time = totalRestTime;
      if (totalRestDistance > 0) c2Payload.rest_distance = totalRestDistance;
    } else {
      c2Payload.workout = { splits: buildSplits(splits) };
    }
  }

  // For interval workouts, C2 expects t/d to reset to 0 at each interval
  // boundary so it can infer which samples belong to which interval.
  if (timeSamples.length > 0) {
    c2Payload.stroke_data = isInterval
      ? buildIntervalStrokeData(timeSamples, segments)
      : buildStrokeData(timeSamples);
  }

  // Device metadata
  if (client_version) c2Payload.client_version = client_version;
  c2Payload.pm_version = 5;
  if (device) c2Payload.device = device;
  if (device_os) c2Payload.device_os = device_os;
  if (device_os_version) c2Payload.device_os_version = device_os_version;

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

    // Persist refreshed tokens (best-effort)
    await supabase
      .from('profiles')
      .update({
        c2_access_token: newAccessToken,
        ...(newRefreshToken ? { c2_refresh_token: newRefreshToken } : {}),
      })
      .eq('id', userId);

    // Retry with the new token
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
      const retryBody = await retryResponse.text().catch(() => '');
      return NextResponse.json(
        { error: `Failed to sync to C2 after token refresh: ${retryResponse.status}`, detail: retryBody },
        { status: retryResponse.status === 401 ? 401 : retryResponse.status === 429 ? 429 : 502 },
      );
    }
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
    const errorBody = await c2Response.text().catch(() => '');
    return NextResponse.json(
      { error: `Failed to sync to C2: ${c2Response.status}`, detail: errorBody },
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
