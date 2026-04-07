import { requireAuth } from '@/lib/supabase/server';
import ProfilePage from './profile-client';

export const metadata = { title: 'Profile — RowCraft' };

export default async function Page() {
  await requireAuth();
  return <ProfilePage />;
}
