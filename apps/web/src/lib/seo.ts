import type { FaqItem } from '@/components/faq-section';

export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://rowcraft.app';

export const ROWCRAFT_ORGANIZATION = {
  '@type': 'Organization' as const,
  name: 'RowCraft',
  url: SITE_URL,
};

export function buildFaqJsonLd(items: FaqItem[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map((faq) => ({
      '@type': 'Question',
      name: faq.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: faq.answer,
      },
    })),
  };
}
