import type { Metadata } from 'next';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { TrainingPlan } from '@/lib/types';
import { PlansClient } from './plans-client';
import { JsonLd } from '@/components/json-ld';
import { SITE_URL } from '@/lib/seo';

export const metadata: Metadata = {
  title: 'Plans — RowCraft',
  description: 'Multi-week rowing training plans for every skill level.',
  alternates: { canonical: '/plans' },
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

  return (
    <>
      <JsonLd data={{
        '@context': 'https://schema.org',
        '@type': 'CollectionPage',
        name: 'Rowing Training Plans',
        description: 'Multi-week rowing training plans for every skill level.',
        url: `${SITE_URL}/plans`,
        mainEntity: {
          '@type': 'ItemList',
          numberOfItems: plans.length,
          itemListElement: plans.map((p, i) => ({
            '@type': 'ListItem',
            position: i + 1,
            url: `${SITE_URL}/plans/${p.slug}`,
            name: p.title,
          })),
        },
      }} />
      <PlansClient plans={plans} userId={user?.id ?? null} />
    </>
  );
}
