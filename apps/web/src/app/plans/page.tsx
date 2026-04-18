import type { Metadata } from 'next';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { TrainingPlan } from '@/lib/types';
import { PlansClient } from './plans-client';

export const metadata: Metadata = {
  title: 'Plans — RowCraft',
  description: 'Multi-week rowing training plans for every skill level.',
};

export default async function PlansPage() {
  const supabase = await createSupabaseServer();
  const user = await getUser();

  const { data } = await supabase
    .from('training_plans')
    .select('*')
    .eq('is_active', true)
    .order('created_at', { ascending: false });

  const plans: TrainingPlan[] = data ?? [];

  return <PlansClient plans={plans} userId={user?.id ?? null} />;
}
