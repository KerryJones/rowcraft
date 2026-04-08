import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="flex min-h-[60vh] items-center justify-center px-4">
      <div className="max-w-md text-center">
        <img src="/logo_gold.svg" alt="" className="mx-auto mb-4 h-16 w-auto opacity-40" />
        <h2 className="mb-2 text-4xl font-bold text-white">404</h2>
        <p className="mb-6 text-sm text-gray-400">
          The page you&apos;re looking for doesn&apos;t exist.
        </p>
        <Link
          href="/workouts"
          className="inline-block rounded-lg bg-blue-600 px-6 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-500"
        >
          Browse Workouts
        </Link>
      </div>
    </div>
  );
}
