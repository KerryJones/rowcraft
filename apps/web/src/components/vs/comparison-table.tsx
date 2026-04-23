import { Check, X, Minus } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { Feature, FeatureSupport } from '@/lib/comparisons';

function SupportIcon({ support }: { support: FeatureSupport }) {
  switch (support) {
    case 'yes':
      return <Check className="h-4 w-4 text-green-400" />;
    case 'no':
      return <X className="h-4 w-4 text-gray-600" />;
    case 'partial':
      return <Minus className="h-4 w-4 text-yellow-400" />;
  }
}

function SupportCell({ support, note }: { support: FeatureSupport; note?: string }) {
  return (
    <div className="flex flex-col items-center gap-0.5">
      <SupportIcon support={support} />
      {note && <span className="text-[10px] leading-tight text-gray-500">{note}</span>}
    </div>
  );
}

export function ComparisonTable({
  features,
  competitorName,
}: {
  features: Feature[];
  competitorName: string;
}) {
  return (
    <div className="overflow-hidden rounded-xl border border-gray-800">
      <div className="grid grid-cols-[1fr_auto_auto] items-center gap-4 border-b border-gray-800 bg-gray-900 px-4 py-3 text-sm font-semibold text-gray-400 sm:grid-cols-[1fr_120px_120px]">
        <span>Feature</span>
        <span className="text-center text-white">RowCraft</span>
        <span className="text-center">{competitorName}</span>
      </div>

      {features.map((feature, i) => (
        <div
          key={feature.name}
          className={cn(
            'grid grid-cols-[1fr_auto_auto] items-center gap-4 px-4 py-3 text-sm sm:grid-cols-[1fr_120px_120px]',
            i % 2 === 0 ? 'bg-gray-950' : 'bg-gray-900/50',
          )}
        >
          <span className="text-gray-300">{feature.name}</span>
          <SupportCell support={feature.rowcraft} note={feature.rowcraftNote} />
          <SupportCell support={feature.competitor} note={feature.competitorNote} />
        </div>
      ))}
    </div>
  );
}
