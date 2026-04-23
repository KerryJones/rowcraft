import Link from 'next/link';
import type { BlogPost } from '@/lib/blog';
import { formatDate } from '@/lib/utils/format';

export function PostCard({ post }: { post: BlogPost }) {
  return (
    <Link
      href={`/blog/${post.slug}`}
      className="block rounded-xl border border-gray-800 bg-gray-900 p-5 transition-colors hover:border-gray-700 hover:bg-gray-800/50"
    >
      <h2 className="mb-2 text-lg font-semibold text-white">{post.title}</h2>
      <p className="mb-3 text-sm leading-relaxed text-gray-400">{post.description}</p>
      <div className="flex flex-wrap items-center gap-2 text-xs text-gray-500">
        <time dateTime={post.date}>{formatDate(post.date)}</time>
        {post.tags.length > 0 && (
          <>
            <span>&middot;</span>
            {post.tags.map((tag) => (
              <span
                key={tag}
                className="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-400"
              >
                {tag}
              </span>
            ))}
          </>
        )}
      </div>
    </Link>
  );
}
