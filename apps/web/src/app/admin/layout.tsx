import { requireAuth } from '@/lib/supabase/server';
import { isAdmin } from '@/lib/supabase/admin';
import { redirect } from 'next/navigation';

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const user = await requireAuth();
  if (!isAdmin(user.email)) {
    redirect('/');
  }
  return <>{children}</>;
}
