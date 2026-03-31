import Link from 'next/link';
import { redirect } from 'next/navigation';
import type { Metadata } from 'next';
import { getUser } from '@/lib/supabase/server';
import { Waves, Bluetooth, Wrench, Calendar, Gauge } from 'lucide-react';

export const metadata: Metadata = {
  title: 'RowCraft — Structured Rowing Workouts',
};

const features = [
  {
    icon: Bluetooth,
    title: 'PM5 Connection',
    description: 'Connect directly to your Concept2 PM5 via Bluetooth for real-time pace, stroke rate, and heart rate.',
  },
  {
    icon: Wrench,
    title: 'Workout Builder',
    description: 'Design custom interval workouts with work, rest, warmup, and cooldown segments.',
  },
  {
    icon: Calendar,
    title: 'Training Plans',
    description: 'Follow structured multi-week training plans designed for every skill level.',
  },
  {
    icon: Gauge,
    title: 'Pace Guidance',
    description: 'FTP-based pace targets and HR zones keep you in the right intensity for every segment.',
  },
];

export default async function LandingPage() {
  const user = await getUser();
  if (user) {
    redirect('/workouts');
  }

  return (
    <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      {/* Hero */}
      <section className="flex flex-col items-center py-24 text-center">
        <Waves className="mb-6 h-16 w-16 text-amber-500" />
        <h1 className="text-5xl font-bold tracking-tight text-white sm:text-6xl">
          RowCraft
        </h1>
        <p className="mt-4 max-w-xl text-lg text-gray-400">
          Structured rowing workouts for the Concept2 PM5. Build intervals, follow training plans,
          and track every meter.
        </p>
        <div className="mt-8 flex gap-4">
          <Link
            href="/workouts"
            className="rounded-lg bg-blue-600 px-6 py-3 font-semibold text-white transition-colors hover:bg-blue-500"
          >
            Browse Workouts
          </Link>
          <Link
            href="/auth/login"
            className="rounded-lg border border-gray-700 px-6 py-3 font-semibold text-gray-300 transition-colors hover:border-gray-600 hover:text-white"
          >
            Get Started
          </Link>
        </div>
      </section>

      {/* Feature grid */}
      <section className="grid gap-6 pb-24 sm:grid-cols-2 lg:grid-cols-4">
        {features.map((feature) => (
          <div
            key={feature.title}
            className="rounded-xl border border-gray-800 bg-gray-900 p-6"
          >
            <feature.icon className="mb-3 h-8 w-8 text-blue-500" />
            <h3 className="mb-2 font-semibold text-white">{feature.title}</h3>
            <p className="text-sm text-gray-400">{feature.description}</p>
          </div>
        ))}
      </section>
    </div>
  );
}
