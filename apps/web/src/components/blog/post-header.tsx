import type { BlogPost } from '@/lib/blog';
import { formatDate } from '@/lib/utils/format';

export function PostHeader({ post }: { post: BlogPost }) {
  return (
    <header className="mb-8">
      <h1 className="mb-3 text-3xl font-bold text-white">{post.title}</h1>
      <div className="flex flex-wrap items-center gap-3 text-sm text-gray-500">
        <time dateTime={post.date}>{formatDate(post.date)}</time>
        {post.tags.length > 0 && (
          <>
            <span>&middot;</span>
            <div className="flex flex-wrap gap-1.5">
              {post.tags.map((tag) => (
                <span
                  key={tag}
                  className="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-400"
                >
                  {tag}
                </span>
              ))}
            </div>
          </>
        )}
      </div>
    </header>
  );
}
