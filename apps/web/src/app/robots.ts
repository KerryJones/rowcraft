import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: ['/admin', '/api/', '/auth/', '/profile', '/history', '/builder', '/plans/builder', '/delete-account'],
    },
    sitemap: `${process.env.NEXT_PUBLIC_SITE_URL ?? 'https://rowcraft.app'}/sitemap.xml`,
  };
}
