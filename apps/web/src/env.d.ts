/// <reference types="@sveltejs/kit" />

declare namespace App {
  interface Locals {
    supabase: import('@supabase/supabase-js').SupabaseClient;
  }

  interface PageData {
    session: import('@supabase/supabase-js').Session | null;
    supabase: import('@supabase/supabase-js').SupabaseClient;
  }
}
