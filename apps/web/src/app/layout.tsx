import type { Metadata } from 'next';
import Link from 'next/link';
import { Header } from '@/components/layout/header';
import { PostHogProvider } from '@/components/posthog-provider';
import './globals.css';
import { Geist } from "next/font/google";
import { cn } from "@/lib/utils";

const geist = Geist({subsets:['latin'],variable:'--font-sans'});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? 'https://rowcraft.app'),
  title: 'RowCraft',
  description: 'Structured rowing workouts for Concept2 rowers',
  manifest: '/site.webmanifest',
  icons: {
    icon: [
      { url: '/favicon.ico', sizes: '16x16 32x32 48x48', type: 'image/x-icon' },
      { url: '/favicon-16x16.png', sizes: '16x16', type: 'image/png' },
      { url: '/favicon-32x32.png', sizes: '32x32', type: 'image/png' },
    ],
    apple: '/apple-touch-icon.png',
  },
  openGraph: {
    siteName: 'RowCraft',
    type: 'website',
    images: [{ url: '/logo.png', width: 512, height: 512, alt: 'RowCraft' }],
  },
  twitter: {
    card: 'summary',
    images: ['/logo.png'],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={cn("dark", "font-sans", geist.variable)}>
      <body className="bg-gray-950 text-white antialiased">
        <div className="flex min-h-screen flex-col">
          <a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-lg focus:bg-blue-600 focus:px-4 focus:py-2 focus:text-sm focus:font-semibold focus:text-white">Skip to content</a>
          <Header />
          <PostHogProvider>
            <main id="main" className="flex-1">{children}</main>
          </PostHogProvider>
          <footer className="border-t border-gray-800 py-8">
            <div className="mx-auto max-w-7xl space-y-3 px-4 text-center text-sm text-gray-500 sm:px-6 lg:px-8">
              <p>RowCraft &mdash; Structured rowing workouts for Concept2 ergometers.</p>
              <p>&copy; 2025–2026 Kerry Jones. All rights reserved.</p>
              <p className="space-x-2">
                <Link href="/terms" className="hover:text-white transition-colors">Terms of Service</Link>
                <span>&middot;</span>
                <Link href="/privacy" className="hover:text-white transition-colors">Privacy Policy</Link>
                <span>&middot;</span>
                <Link href="/contact" className="hover:text-white transition-colors">Contact</Link>
                <span>&middot;</span>
                <Link href="/blog" className="hover:text-white transition-colors">Blog</Link>
                <span>&middot;</span>
                <a href="https://buymeacoffee.com/kerryjones" target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">Support</a>
              </p>
              <p className="text-xs text-gray-600">
                Not affiliated with or endorsed by Concept2, Inc. Concept2&reg; is a registered trademark of Concept2, Inc.
              </p>
            </div>
          </footer>
        </div>
      </body>
    </html>
  );
}
