import type { Metadata } from 'next';
import Link from 'next/link';
import { getAllComparisons, pricingLabel } from '@/lib/comparisons';
import { JsonLd } from '@/components/json-ld';
import { SITE_URL } from '@/lib/seo';

export const metadata: Metadata = {
  title: 'RowCraft vs Competitors — Honest Comparisons',
  description:
    'Honest feature comparisons between RowCraft and other rowing apps. See where RowCraft shines and where competitors do it better.',
  alternates: { canonical: '/vs' },
};

export default function ComparisonsPage() {
  const comparisons = getAllComparisons();

  return (
    <>
      <JsonLd
        data={{
          '@context': 'https://schema.org',
          '@type': 'CollectionPage',
          name: 'RowCraft vs Competitors',
          description: metadata.description,
          url: `${SITE_URL}/vs`,
          mainEntity: {
            '@type': 'ItemList',
            numberOfItems: comparisons.length,
            itemListElement: comparisons.map((c, i) => ({
              '@type': 'ListItem',
              position: i + 1,
              url: `${SITE_URL}/vs/${c.slug}`,
              name: `RowCraft vs ${c.name}`,
            })),
          },
        }}
      />
      <div className="mx-auto max-w-3xl px-4 py-12 sm:px-6">
        <h1 className="mb-2 text-3xl font-bold text-white">RowCraft vs Competitors</h1>
        <p className="mb-8 text-gray-400">
          Honest feature comparisons. We tell you where RowCraft is better — and where competitors
          have the edge.
        </p>
        <div className="space-y-4">
          {comparisons.map((c) => (
            <Link
              key={c.slug}
              href={`/vs/${c.slug}`}
              className="block rounded-xl border border-gray-800 bg-gray-900 p-5 transition-colors hover:border-gray-700 hover:bg-gray-800/50"
            >
              <div className="mb-2 flex items-center justify-between">
                <h2 className="text-lg font-semibold text-white">RowCraft vs {c.name}</h2>
                <span className="text-xs text-gray-500">{pricingLabel(c.pricing)}</span>
              </div>
              <p className="text-sm leading-relaxed text-gray-400">{c.tagline}</p>
            </Link>
          ))}
        </div>
      </div>
    </>
  );
}
