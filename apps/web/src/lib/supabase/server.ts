import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { createClient } from '@supabase/supabase-js';
import { cookies } from 'next/headers';
import { type NextRequest } from 'next/server';
import { redirect } from 'next/navigation';

export async function createSupabaseServer() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, {
                path: options.path,
                maxAge: options.maxAge,
                domain: options.domain,
                secure: options.secure,
                httpOnly: options.httpOnly,
                sameSite: options.sameSite as 'lax' | 'strict' | 'none' | undefined,
              });
            });
          } catch {
            // setAll is called from Server Components where cookies can't be set.
            // This is fine — middleware handles the refresh.
          }
        },
      },
    },
  );
}

export async function getUser() {
  const supabase = await createSupabaseServer();
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

/**
 * Authenticate an API route request from either mobile (Bearer token)
 * or web (cookie session). Returns the user ID or null.
 */
export async function getAuthenticatedUserId(request: NextRequest): Promise<string | null> {
  const authHeader = request.headers.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    return user?.id ?? null;
  }
  const supabase = await createSupabaseServer();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id ?? null;
}

export async function requireAuth() {
  const user = await getUser();
  if (!user) {
    redirect('/auth/login');
  }
  return user;
}
