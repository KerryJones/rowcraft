import type { MetadataRoute } from 'next';
import { createSupabaseAdmin } from '@/lib/supabase/admin';
import { getAllPosts } from '@/lib/blog';
import { getAllComparisons } from '@/lib/comparisons';

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://rowcraft.app';

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const staticPages: MetadataRoute.Sitemap = [
    { url: BASE_URL, changeFrequency: 'weekly', priority: 1 },
    { url: `${BASE_URL}/workouts`, changeFrequency: 'daily', priority: 0.9 },
    { url: `${BASE_URL}/workouts/wod`, changeFrequency: 'daily', priority: 0.8 },
    { url: `${BASE_URL}/plans`, changeFrequency: 'weekly', priority: 0.8 },
    { url: `${BASE_URL}/blog`, changeFrequency: 'weekly', priority: 0.8 },
    { url: `${BASE_URL}/contact`, changeFrequency: 'monthly', priority: 0.3 },
    { url: `${BASE_URL}/privacy`, changeFrequency: 'monthly', priority: 0.2 },
    { url: `${BASE_URL}/terms`, changeFrequency: 'monthly', priority: 0.2 },
    { url: `${BASE_URL}/vs`, changeFrequency: 'monthly', priority: 0.7 },
  ];

  const supabase = createSupabaseAdmin();

  const blogPosts = getAllPosts();

  const plansRes = await supabase
    .from('training_plans')
    .select('slug, updated_at')
    .eq('is_active', true)
    .order('updated_at', { ascending: false });

  if (plansRes.error) console.error('Sitemap: plans query failed:', plansRes.error.message);

  // Individual workout pages are intentionally excluded from the sitemap.
  // They are thin pages that Google deprioritises. The /workouts listing page
  // is included above, and individual workout pages remain crawlable via
  // internal links so Google can discover them organically.

  const planPages: MetadataRoute.Sitemap = (plansRes.data ?? []).map((p) => ({
    url: `${BASE_URL}/plans/${p.slug}`,
    lastModified: p.updated_at,
    changeFrequency: 'weekly',
    priority: 0.7,
  }));

  const blogPages: MetadataRoute.Sitemap = blogPosts.map((p) => ({
    url: `${BASE_URL}/blog/${p.slug}`,
    lastModified: p.date,
    changeFrequency: 'monthly',
    priority: 0.7,
  }));

  const comparisonPages: MetadataRoute.Sitemap = getAllComparisons().map((c) => ({
    url: `${BASE_URL}/vs/${c.slug}`,
    lastModified: c.lastUpdated,
    changeFrequency: 'monthly',
    priority: 0.7,
  }));

  return [...staticPages, ...planPages, ...blogPages, ...comparisonPages];
}
