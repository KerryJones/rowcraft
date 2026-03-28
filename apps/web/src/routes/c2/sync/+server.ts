import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createSupabaseServerClient } from '$lib/server/supabase';

export const POST: RequestHandler = async ({ request, cookies }) => {
	// Verify user session
	const supabase = createSupabaseServerClient(cookies);
	const { data: { user } } = await supabase.auth.getUser();
	if (!user) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	// Get C2 tokens from profile
	const { data: profile } = await supabase
		.from('profiles')
		.select('c2_access_token, c2_user_id')
		.eq('id', user.id)
		.single();

	if (!profile?.c2_access_token) {
		return json({ error: 'C2 Logbook not linked' }, { status: 400 });
	}

	// Parse and validate request body
	let result: Record<string, unknown>;
	try {
		result = await request.json();
	} catch {
		return json({ error: 'Invalid JSON body' }, { status: 400 });
	}

	if (
		typeof result.started_at !== 'string' ||
		typeof result.total_distance !== 'number' ||
		typeof result.total_time !== 'number'
	) {
		return json({ error: 'Missing or invalid required fields: started_at (string), total_distance (number), total_time (number)' }, { status: 400 });
	}

	// Upload to C2 Logbook
	const c2Response = await fetch(
		`https://log.concept2.com/api/users/${profile.c2_user_id}/results`,
		{
			method: 'POST',
			headers: {
				Authorization: `Bearer ${profile.c2_access_token}`,
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({
				type: 'rower',
				date: result.started_at,
				distance: result.total_distance,
				time: result.total_time,
				...(typeof result.avg_stroke_rate === 'number' && { stroke_rate: result.avg_stroke_rate }),
				...(typeof result.avg_heart_rate === 'number' && { heart_rate: { average: result.avg_heart_rate } })
			})
		}
	);

	if (!c2Response.ok) {
		console.error('C2 sync failed:', c2Response.status);
		return json({ error: 'C2 sync failed' }, { status: 400 });
	}

	// Parse C2 response (tolerate non-JSON 2xx responses)
	let c2ResultId: unknown;
	try {
		const c2Result = await c2Response.json();
		c2ResultId = c2Result.data?.id;
	} catch {
		console.error('C2 returned non-JSON success response:', c2Response.status);
	}

	// Mark result as synced
	if (typeof result.id === 'string') {
		const { error: markError } = await supabase
			.from('workout_results')
			.update({ synced_to_c2: true })
			.eq('id', result.id)
			.eq('user_id', user.id);
		if (markError) {
			console.error('Failed to mark result as synced:', markError.message);
		}
	}

	return json({ success: true, ...(c2ResultId != null && { c2_result_id: c2ResultId }) });
};
