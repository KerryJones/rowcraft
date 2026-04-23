import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';
import { cache } from 'react';

const CONTENT_DIR = path.join(process.cwd(), 'src', 'content', 'blog');

const VALID_SLUG = /^[a-z0-9-]+$/;

export interface BlogPost {
  slug: string;
  title: string;
  description: string;
  date: string;
  author: string;
  tags: string[];
}

export interface BlogPostWithContent extends BlogPost {
  content: string;
}

function normalizeDate(value: unknown): string {
  return value instanceof Date ? value.toISOString().slice(0, 10) : String(value);
}

function parsePost(slug: string, raw: string): BlogPost | null {
  const { data } = matter(raw);

  if (!data.published) return null;
  if (!data.title || !data.description || !data.date) return null;

  return {
    slug,
    title: data.title,
    description: data.description,
    date: normalizeDate(data.date),
    author: data.author ?? 'Kerry Jones',
    tags: Array.isArray(data.tags) ? data.tags : [],
  };
}

export const getAllPosts = cache(function getAllPosts(): BlogPost[] {
  const files = fs.readdirSync(CONTENT_DIR);
  const posts: BlogPost[] = [];

  for (const filename of files) {
    if (filename.startsWith('_') || !filename.endsWith('.mdx')) continue;
    const raw = fs.readFileSync(path.join(CONTENT_DIR, filename), 'utf-8');
    const post = parsePost(filename.replace(/\.mdx$/, ''), raw);
    if (post) posts.push(post);
  }

  return posts.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
});

export const getPostBySlug = cache(function getPostBySlug(slug: string): BlogPostWithContent | null {
  if (!VALID_SLUG.test(slug)) return null;

  let raw: string;
  try {
    raw = fs.readFileSync(path.join(CONTENT_DIR, `${slug}.mdx`), 'utf-8');
  } catch {
    return null;
  }

  const { data, content } = matter(raw);

  if (!data.published) return null;
  if (!data.title || !data.description || !data.date) return null;

  return {
    slug,
    title: data.title,
    description: data.description,
    date: normalizeDate(data.date),
    author: data.author ?? 'Kerry Jones',
    tags: Array.isArray(data.tags) ? data.tags : [],
    content,
  };
});

export function getAllSlugs(): string[] {
  return fs
    .readdirSync(CONTENT_DIR)
    .filter((f) => !f.startsWith('_') && f.endsWith('.mdx'))
    .map((f) => f.replace(/\.mdx$/, ''))
    .filter((slug) => VALID_SLUG.test(slug));
}
