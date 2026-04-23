import type { Metadata } from 'next';
import { getAllPosts } from '@/lib/blog';
import { PostCard } from '@/components/blog/post-card';
import { JsonLd } from '@/components/json-ld';
import { SITE_URL } from '@/lib/seo';

export const metadata: Metadata = {
  title: 'Blog — RowCraft',
  description: 'Training guides, workout breakdowns, and rowing knowledge for Concept2 rowers.',
  alternates: { canonical: '/blog' },
};

export default function BlogPage() {
  const posts = getAllPosts();

  return (
    <>
      <JsonLd data={{
        '@context': 'https://schema.org',
        '@type': 'CollectionPage',
        name: 'RowCraft Blog',
        description: 'Training guides, workout breakdowns, and rowing knowledge for Concept2 rowers.',
        url: `${SITE_URL}/blog`,
        mainEntity: {
          '@type': 'ItemList',
          numberOfItems: posts.length,
          itemListElement: posts.map((p, i) => ({
            '@type': 'ListItem',
            position: i + 1,
            url: `${SITE_URL}/blog/${p.slug}`,
            name: p.title,
          })),
        },
      }} />
      <div className="mx-auto max-w-3xl px-4 py-12 sm:px-6">
        <h1 className="mb-2 text-3xl font-bold text-white">Blog</h1>
        <p className="mb-8 text-gray-400">Training guides, workout breakdowns, and rowing knowledge for Concept2 rowers.</p>
        <div className="space-y-4">
          {posts.map((post) => (
            <PostCard key={post.slug} post={post} />
          ))}
        </div>
      </div>
    </>
  );
}
