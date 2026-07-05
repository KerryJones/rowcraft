import { NextRequest, NextResponse } from 'next/server';
import { createSupabaseAdmin } from '@/lib/supabase/admin';
import { getAuthenticatedUserId } from '@/lib/supabase/server';

export type OAuthProvider = 'c2' | 'strava';

/** Handoff ids are single-use and expire quickly. */
export const HANDOFF_MAX_AGE_MS = 10 * 60 * 1000;

/** Pure expiry check, exported for tests. */
export function isHandoffExpired(createdAt: string, now: Date): boolean {
  const created = new Date(createdAt).getTime();
  if (Number.isNaN(created)) return true;
  return now.getTime() - created > HANDOFF_MAX_AGE_MS;
}

/**
 * POST handler body for /api/<provider>/auth/start.
 *
 * Authenticates the mobile caller via the Authorization header and mints a
 * one-time handoff id the browser can carry in the URL instead of the
 * Supabase access token.
 */
export async function createOAuthHandoff(
  request: NextRequest,
  provider: OAuthProvider,
): Promise<NextResponse> {
  const userId = await getAuthenticatedUserId(request);
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const supabase = createSupabaseAdmin();
  const { data, error } = await supabase
    .from('oauth_handoff')
    .insert({ user_id: userId, provider })
    .select('id')
    .single();

  if (error || !data) {
    return NextResponse.json(
      { error: 'Failed to create handoff' },
      { status: 500 },
    );
  }

  return NextResponse.json({ handoff: data.id });
}

/**
 * Redeem a one-time handoff id from the OAuth kick-off URL.
 * Returns the user id, or null when the id is unknown, expired, or for a
 * different provider. The row is always deleted (single use).
 */
export async function consumeOAuthHandoff(
  handoffId: string,
  provider: OAuthProvider,
): Promise<string | null> {
  const supabase = createSupabaseAdmin();

  // Delete-returning makes redemption atomic: two racing requests can't
  // both succeed with the same id.
  const { data, error } = await supabase
    .from('oauth_handoff')
    .delete()
    .eq('id', handoffId)
    .eq('provider', provider)
    .select('user_id, created_at')
    .single();

  if (error || !data) return null;
  if (isHandoffExpired(data.created_at, new Date())) return null;
  return data.user_id;
}
