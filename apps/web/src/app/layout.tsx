import type { Metadata } from 'next';
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
            <div className="mx-auto max-w-7xl px-4 text-center text-sm text-gray-500 sm:px-6 lg:px-8">
              RowCraft &mdash; Structured rowing workouts for Concept2 ergometers.
            </div>
          </footer>
        </div>
      </body>
    </html>
  );
}
