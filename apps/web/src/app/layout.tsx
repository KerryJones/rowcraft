import type { Metadata } from 'next';
import Link from 'next/link';
import { Header } from '@/components/layout/header';
import './globals.css';
import { Geist } from "next/font/google";
import { cn } from "@/lib/utils";

const geist = Geist({subsets:['latin'],variable:'--font-sans'});

export const metadata: Metadata = {
  title: 'RowCraft',
  description: 'Structured rowing workouts for Concept2 rowers',
  icons: { icon: '/favicon.svg' },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={cn("dark", "font-sans", geist.variable)}>
      <body className="bg-gray-950 text-white antialiased">
        <div className="flex min-h-screen flex-col">
          <Header />
          <main className="flex-1">{children}</main>
          <footer className="border-t border-gray-800 py-8">
            <div className="mx-auto max-w-7xl space-y-3 px-4 text-center text-sm text-gray-500 sm:px-6 lg:px-8">
              <p>RowCraft &mdash; Structured rowing workouts for Concept2 ergometers.</p>
              <p>&copy; 2025–2026 Kerry Jones. All rights reserved.</p>
              <p className="space-x-2">
                <Link href="/terms" className="hover:text-white transition-colors">Terms of Service</Link>
                <span>&middot;</span>
                <Link href="/privacy" className="hover:text-white transition-colors">Privacy Policy</Link>
                <span>&middot;</span>
                <a href="mailto:kerry@kerryjones.net" className="hover:text-white transition-colors">Contact</a>
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
