import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { getAllComparisons, getComparisonBySlug, pricingLabel } from '@/lib/comparisons';
import { ComparisonTable } from '@/components/vs/comparison-table';
import { VerdictCard } from '@/components/vs/verdict-card';
import { ComparisonCta } from '@/components/vs/comparison-cta';
import { JsonLd } from '@/components/json-ld';
import { SITE_URL } from '@/lib/seo';
import { formatDate } from '@/lib/utils/format';

interface Props {
  params: Promise<{ slug: string }>;
}

export const dynamicParams = false;

export async function generateStaticParams() {
  return getAllComparisons().map((c) => ({ slug: c.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const competitor = getComparisonBySlug(slug);
  if (!competitor) return { title: 'Comparison Not Found — RowCraft' };

  return {
    title: competitor.metaTitle,
    description: competitor.metaDescription,
    alternates: { canonical: `/vs/${slug}` },
    openGraph: {
      title: competitor.metaTitle,
      description: competitor.metaDescription,
      type: 'website',
    },
  };
}

export default async function ComparisonPage({ params }: Props) {
  const { slug } = await params;
  const competitor = getComparisonBySlug(slug);
  if (!competitor) notFound();

  const others = getAllComparisons().filter((c) => c.slug !== slug);

  return (
    <>
      <JsonLd
        data={{
          '@context': 'https://schema.org',
          '@type': 'WebPage',
          name: `RowCraft vs ${competitor.name}`,
          description: competitor.metaDescription,
          url: `${SITE_URL}/vs/${competitor.slug}`,
          about: [
            {
              '@type': 'SoftwareApplication',
              name: 'RowCraft',
              applicationCategory: 'SportsApplication',
              operatingSystem: 'Android, Web',
              offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
            },
            {
              '@type': 'SoftwareApplication',
              name: competitor.name,
              url: competitor.website,
              applicationCategory: 'SportsApplication',
              offers: {
                '@type': 'Offer',
                price: String(competitor.priceMonthly),
                priceCurrency: 'USD',
              },
            },
          ],
        }}
      />
      <div className="mx-auto max-w-3xl space-y-10 px-4 py-12 sm:px-6">
        <div>
          <h1 className="mb-2 text-3xl font-bold text-white">
            RowCraft vs {competitor.name}
          </h1>
          <p className="mb-2 text-gray-400">{competitor.tagline}</p>
          <div className="mb-4 flex gap-3 text-sm">
            <span className="rounded-full bg-blue-950/40 px-3 py-1 text-blue-400">
              RowCraft — Free
            </span>
            <span className="rounded-full bg-gray-800 px-3 py-1 text-gray-400">
              {competitor.name} — {competitor.pricing}
            </span>
          </div>
          <p className="text-sm leading-relaxed text-gray-300">{competitor.intro}</p>
        </div>

        <section>
          <h2 className="mb-4 text-lg font-semibold text-white">Feature Comparison</h2>
          <ComparisonTable features={competitor.features} competitorName={competitor.name} />
        </section>

        {[
          { title: `Where ${competitor.name} Shines`, items: competitor.competitorStrengths },
          { title: 'Where RowCraft Shines', items: competitor.rowcraftStrengths },
        ].map(({ title, items }) => (
          <section key={title}>
            <h2 className="mb-4 text-lg font-semibold text-white">{title}</h2>
            <ul className="space-y-3">
              {items.map((strength) => (
                <li key={strength} className="text-sm leading-relaxed text-gray-300">
                  {strength}
                </li>
              ))}
            </ul>
          </section>
        ))}

        <VerdictCard competitor={competitor} />

        <ComparisonCta />

        <section>
          <h2 className="mb-4 text-lg font-semibold text-white">More Comparisons</h2>
          <div className="space-y-2">
            {others.map((c) => (
              <Link
                key={c.slug}
                href={`/vs/${c.slug}`}
                className="block rounded-lg border border-gray-800 px-4 py-3 text-sm text-gray-400 transition-colors hover:border-gray-700 hover:text-white"
              >
                RowCraft vs {c.name}
                <span className="ml-2 text-xs text-gray-600">{pricingLabel(c.pricing)}</span>
              </Link>
            ))}
          </div>
        </section>

        <p className="text-xs text-gray-600">
          Last updated: {formatDate(competitor.lastUpdated)}. Feature information is based on publicly available
          data and may change. Visit{' '}
          <a
            href={competitor.website}
            target="_blank"
            rel="noopener noreferrer"
            className="text-gray-500 hover:text-gray-400"
          >
            {competitor.name}&apos;s website
          </a>{' '}
          for the most current information.
        </p>
      </div>
    </>
  );
}
