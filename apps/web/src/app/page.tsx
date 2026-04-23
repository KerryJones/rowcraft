import Link from 'next/link';
import { redirect } from 'next/navigation';
import type { Metadata } from 'next';
import { getUser } from '@/lib/supabase/server';
import { Bluetooth, Wrench, Calendar, Gauge } from 'lucide-react';
import { JsonLd } from '@/components/json-ld';
import { FaqSection, type FaqItem } from '@/components/faq-section';
import { SITE_URL, ROWCRAFT_ORGANIZATION, buildFaqJsonLd } from '@/lib/seo';

export const metadata: Metadata = {
  title: 'RowCraft — Structured Rowing Workouts',
  description: 'Build custom interval workouts, follow training plans, and connect to your Concept2 rower via Bluetooth.',
  alternates: { canonical: '/' },
};

const features = [
  {
    icon: Bluetooth,
    title: 'Rower Connection',
    description: 'Connect directly to your Concept2 rower via Bluetooth for real-time pace, stroke rate, and heart rate.',
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

const landingFaqs: FaqItem[] = [
  {
    question: 'What is RowCraft?',
    answer: 'RowCraft is a free platform for creating and following structured rowing workouts on Concept2 ergometers. It includes a library of 130+ workouts, multi-week training plans, and a custom workout builder with FTP-based pace guidance.',
  },
  {
    question: 'Does RowCraft work with my Concept2 rower?',
    answer: 'RowCraft connects to the Concept2 PM5 monitor via Bluetooth. During a workout, it displays real-time pace, stroke rate, and heart rate data alongside your targets for each segment.',
  },
  {
    question: 'Is RowCraft free?',
    answer: 'Yes. RowCraft is completely free to use. There are no subscriptions, ads, or paywalls. All workouts, training plans, and features are available at no cost.',
  },
  {
    question: 'How does pace guidance work?',
    answer: 'Each workout segment has a target intensity based on your FTP (Functional Threshold Power). RowCraft converts this into a pace target displayed as minutes per 500 meters, so you always know exactly how hard to pull for each interval.',
  },
];

export default async function LandingPage() {
  const user = await getUser();
  if (user) {
    redirect('/workouts');
  }

  return (
    <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <JsonLd data={[
        {
          '@context': 'https://schema.org',
          '@type': 'SoftwareApplication',
          name: 'RowCraft',
          url: SITE_URL,
          description: 'Build custom interval workouts, follow training plans, and connect to your Concept2 rower via Bluetooth for real-time pace guidance.',
          applicationCategory: 'SportsApplication',
          operatingSystem: 'Android, Web',
          offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
          author: { '@type': 'Person', name: 'Kerry Jones' },
        },
        {
          '@context': 'https://schema.org',
          ...ROWCRAFT_ORGANIZATION,
          logo: `${SITE_URL}/logo.png`,
          email: 'support@rowcraft.app',
          sameAs: ['https://buymeacoffee.com/kerryjones'],
        },
      ]} />
      {/* Hero */}
      <section className="flex flex-col items-center py-24 text-center">
        <img src="/logo_gold.svg" alt="RowCraft" className="mb-6 h-16 w-auto" fetchPriority="high" />
        <h1 className="text-5xl font-bold tracking-tight text-white sm:text-6xl">
          RowCraft
        </h1>
        <p className="mt-4 max-w-xl text-lg text-gray-400">
          Structured rowing workouts for the Concept2 rower. Build intervals, follow training plans,
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
      <section className="grid gap-6 pb-16 sm:grid-cols-2 lg:grid-cols-4">
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

      {/* FAQ */}
      <section className="pb-24">
        <JsonLd data={buildFaqJsonLd(landingFaqs)} />
        <FaqSection items={landingFaqs} />
      </section>
    </div>
  );
}
