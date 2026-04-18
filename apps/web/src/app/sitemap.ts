import type { MetadataRoute } from 'next';
import { createSupabaseAdmin } from '@/lib/supabase/admin';

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://rowing.kerryjones.net';

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const staticPages: MetadataRoute.Sitemap = [
    { url: BASE_URL, changeFrequency: 'weekly', priority: 1 },
    { url: `${BASE_URL}/workouts`, changeFrequency: 'daily', priority: 0.9 },
    { url: `${BASE_URL}/workouts/wod`, changeFrequency: 'daily', priority: 0.8 },
    { url: `${BASE_URL}/plans`, changeFrequency: 'weekly', priority: 0.8 },
    { url: `${BASE_URL}/contact`, changeFrequency: 'monthly', priority: 0.3 },
    { url: `${BASE_URL}/privacy`, changeFrequency: 'monthly', priority: 0.2 },
    { url: `${BASE_URL}/terms`, changeFrequency: 'monthly', priority: 0.2 },
  ];

  const supabase = createSupabaseAdmin();

  const [workoutsRes, plansRes] = await Promise.all([
    supabase
      .from('workouts')
      .select('id, updated_at')
      .eq('is_public', true)
      .order('updated_at', { ascending: false }),
    supabase
      .from('training_plans')
      .select('slug, updated_at')
      .eq('is_active', true)
      .order('updated_at', { ascending: false }),
  ]);

  if (workoutsRes.error) console.error('Sitemap: workouts query failed:', workoutsRes.error.message);
  if (plansRes.error) console.error('Sitemap: plans query failed:', plansRes.error.message);

  const workoutPages: MetadataRoute.Sitemap = (workoutsRes.data ?? []).map((w) => ({
    url: `${BASE_URL}/workouts/${w.id}`,
    lastModified: w.updated_at,
    changeFrequency: 'monthly',
    priority: 0.6,
  }));

  const planPages: MetadataRoute.Sitemap = (plansRes.data ?? []).map((p) => ({
    url: `${BASE_URL}/plans/${p.slug}`,
    lastModified: p.updated_at,
    changeFrequency: 'weekly',
    priority: 0.7,
  }));

  return [...staticPages, ...workoutPages, ...planPages];
}
