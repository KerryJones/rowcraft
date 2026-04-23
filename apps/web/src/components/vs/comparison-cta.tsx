import Link from 'next/link';

export function ComparisonCta() {
  return (
    <section className="rounded-xl border border-gray-800 bg-gray-900 p-8 text-center">
      <h2 className="mb-2 text-lg font-semibold text-white">Ready to try RowCraft?</h2>
      <p className="mb-6 text-sm text-gray-400">
        Free structured workouts, training plans, and pace guidance. No subscription required.
      </p>
      <div className="flex justify-center gap-4">
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
  );
}
