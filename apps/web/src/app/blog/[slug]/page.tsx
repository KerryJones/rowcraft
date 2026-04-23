import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { MDXRemote } from 'next-mdx-remote/rsc';
import remarkGfm from 'remark-gfm';
import { getAllSlugs, getPostBySlug } from '@/lib/blog';
import { PostHeader } from '@/components/blog/post-header';
import { JsonLd } from '@/components/json-ld';
import { SITE_URL, ROWCRAFT_ORGANIZATION } from '@/lib/seo';

interface Props {
  params: Promise<{ slug: string }>;
}

export const dynamicParams = false;

export async function generateStaticParams() {
  return getAllSlugs().map((slug) => ({ slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const post = getPostBySlug(slug);
  if (!post) return { title: 'Post Not Found — RowCraft' };

  return {
    title: `${post.title} — RowCraft`,
    description: post.description,
    alternates: { canonical: `/blog/${slug}` },
    openGraph: {
      title: post.title,
      description: post.description,
      type: 'article',
      publishedTime: post.date,
      authors: [post.author],
    },
  };
}

export default async function BlogPostPage({ params }: Props) {
  const { slug } = await params;
  const post = getPostBySlug(slug);
  if (!post) notFound();

  return (
    <>
      <JsonLd data={{
        '@context': 'https://schema.org',
        '@type': 'Article',
        headline: post.title,
        description: post.description,
        datePublished: post.date,
        author: { '@type': 'Person', name: post.author },
        publisher: ROWCRAFT_ORGANIZATION,
        url: `${SITE_URL}/blog/${post.slug}`,
      }} />
      <article className="mx-auto max-w-3xl px-4 py-12 sm:px-6">
        <PostHeader post={post} />
        <div className="prose prose-sm prose-invert prose-gray max-w-none leading-relaxed text-gray-300 prose-headings:text-white prose-a:text-blue-400 prose-strong:text-white">
          <MDXRemote source={post.content} options={{ mdxOptions: { remarkPlugins: [remarkGfm] } }} />
        </div>
      </article>
    </>
  );
}
