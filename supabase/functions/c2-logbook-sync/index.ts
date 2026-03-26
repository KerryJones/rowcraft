import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const C2_AUTH_URL = 'https://log.concept2.com/oauth/authorize';
const C2_TOKEN_URL = 'https://log.concept2.com/oauth/access_token';
const C2_API_URL = 'https://log.concept2.com/api';
const C2_CLIENT_ID = Deno.env.get('C2_CLIENT_ID') ?? '';
const C2_CLIENT_SECRET = Deno.env.get('C2_CLIENT_SECRET') ?? '';
const C2_REDIRECT_URI = Deno.env.get('C2_REDIRECT_URI') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const path = url.pathname.split('/').pop();

  try {
    switch (path) {
      case 'auth':
        return handleAuth(url);
      case 'callback':
        return await handleCallback(url, req);
      case 'sync':
        return await handleSync(req);
      default:
        return new Response(JSON.stringify({ error: 'Not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

function handleAuth(url: URL): Response {
  const state = url.searchParams.get('state') ?? crypto.randomUUID();
  const authUrl = new URL(C2_AUTH_URL);
  authUrl.searchParams.set('client_id', C2_CLIENT_ID);
  authUrl.searchParams.set('redirect_uri', C2_REDIRECT_URI);
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('scope', 'user:read,results:write');
  authUrl.searchParams.set('state', state);

  return new Response(null, {
    status: 302,
    headers: { ...corsHeaders, Location: authUrl.toString() },
  });
}

async function handleCallback(url: URL, req: Request): Promise<Response> {
  // Authenticate the caller FIRST — before any external requests
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing auth header' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const { data: { user } } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));

  if (!user) {
    return new Response(JSON.stringify({ error: 'Invalid user' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Read code from query string (browser redirect) or request body (mobile POST)
  let code = url.searchParams.get('code');
  if (!code && req.method === 'POST') {
    try {
      const body = await req.json();
      code = body.code ?? null;
    } catch {
      // Body parse failed — code stays null
    }
  }
  if (!code) {
    return new Response(JSON.stringify({ error: 'Missing authorization code' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Exchange code for tokens (only after auth is verified)
  const tokenResponse = await fetch(C2_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      client_id: C2_CLIENT_ID,
      client_secret: C2_CLIENT_SECRET,
      redirect_uri: C2_REDIRECT_URI,
    }),
  });

  if (!tokenResponse.ok) {
    const error = await tokenResponse.text();
    return new Response(JSON.stringify({ error: `Token exchange failed: ${error}` }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const tokens = await tokenResponse.json();

  // Get C2 user info
  const userResponse = await fetch(`${C2_API_URL}/users/me`, {
    headers: { Authorization: `Bearer ${tokens.access_token}` },
  });
  if (!userResponse.ok) {
    return new Response(JSON.stringify({ error: 'Failed to fetch C2 user info' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  const c2User = await userResponse.json();
  if (!c2User?.data?.id) {
    return new Response(JSON.stringify({ error: 'Invalid C2 user response' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Store tokens in profile
  await supabase
    .from('profiles')
    .update({
      c2_user_id: String(c2User.data.id),
      c2_access_token: tokens.access_token,
      c2_refresh_token: tokens.refresh_token,
    })
    .eq('id', user.id);

  return new Response(JSON.stringify({ success: true, c2_user_id: c2User.data.id }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function handleSync(req: Request): Promise<Response> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing auth header' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const { data: { user } } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));

  if (!user) {
    return new Response(JSON.stringify({ error: 'Invalid user' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Get profile with C2 tokens
  const { data: profile } = await supabase
    .from('profiles')
    .select('c2_access_token, c2_user_id')
    .eq('id', user.id)
    .single();

  if (!profile?.c2_access_token) {
    return new Response(JSON.stringify({ error: 'C2 Logbook not linked' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Get workout result from request body
  const result = await req.json();

  // Upload to C2 Logbook
  const c2Response = await fetch(`${C2_API_URL}/users/${profile.c2_user_id}/results`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${profile.c2_access_token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      type: 'rower',
      date: result.started_at,
      distance: result.total_distance,
      time: result.total_time,
      stroke_rate: result.avg_stroke_rate,
      heart_rate: result.avg_heart_rate ? { average: result.avg_heart_rate } : undefined,
    }),
  });

  if (!c2Response.ok) {
    const error = await c2Response.text();
    return new Response(JSON.stringify({ error: `C2 sync failed: ${error}` }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Mark result as synced
  if (result.id) {
    await supabase
      .from('workout_results')
      .update({ synced_to_c2: true })
      .eq('id', result.id)
      .eq('user_id', user.id);
  }

  const c2Result = await c2Response.json();
  return new Response(JSON.stringify({ success: true, c2_result_id: c2Result.data?.id }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
