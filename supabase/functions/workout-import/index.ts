import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
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

    const { workout_id } = await req.json();

    if (!workout_id) {
      return new Response(JSON.stringify({ error: 'Missing workout_id' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Get the source workout
    const { data: sourceWorkout, error: fetchError } = await supabase
      .from('workouts')
      .select('*')
      .eq('id', workout_id)
      .single();

    if (fetchError || !sourceWorkout) {
      return new Response(JSON.stringify({ error: 'Workout not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Check if it's public or belongs to the user
    if (!sourceWorkout.is_public && sourceWorkout.author_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Workout not accessible' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Create a fork
    const { data: forkedWorkout, error: insertError } = await supabase
      .from('workouts')
      .insert({
        author_id: user.id,
        title: sourceWorkout.title,
        description: sourceWorkout.description,
        workout_type: sourceWorkout.workout_type,
        segments: sourceWorkout.segments,
        tags: sourceWorkout.tags,
        is_public: false,
        forked_from: workout_id,
      })
      .select()
      .single();

    if (insertError) {
      return new Response(JSON.stringify({ error: `Fork failed: ${insertError.message}` }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Increment fork count on source
    await supabase.rpc('increment_fork_count', { workout_id });

    return new Response(JSON.stringify({ success: true, workout: forkedWorkout }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
