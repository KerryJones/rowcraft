import type { Competitor } from '@/lib/comparisons';

export function VerdictCard({ competitor }: { competitor: Competitor }) {
  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 p-6">
      <h2 className="mb-4 text-lg font-semibold text-white">The Verdict</h2>
      <p className="mb-6 text-sm leading-relaxed text-gray-300">{competitor.verdict}</p>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="rounded-lg border border-gray-800 bg-gray-950 p-4">
          <p className="mb-1 text-xs font-medium text-gray-500">Choose {competitor.name} if you want</p>
          <p className="text-sm text-gray-300">{competitor.bestFor}</p>
          <p className="mt-2 text-xs text-gray-500">{competitor.pricing}</p>
        </div>
        <div className="rounded-lg border border-blue-900/50 bg-blue-950/20 p-4">
          <p className="mb-1 text-xs font-medium text-blue-400">Choose RowCraft if you want</p>
          <p className="text-sm text-gray-300">{competitor.rowcraftBestFor}</p>
          <p className="mt-2 text-xs text-blue-400/70">Free</p>
        </div>
      </div>
    </div>
  );
}
