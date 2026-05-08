'use client';

import type { ZoneSystem } from '@/lib/types';
import { HR_ZONES } from '@/lib/utils/ftp';
import { HR_ZONE_COLORS } from '@/lib/utils/segment-color';
import {
	Accordion,
	AccordionContent,
	AccordionItem,
	AccordionTrigger,
} from '@/components/ui/accordion';

interface HrZoneLegendProps {
	zoneSystem: ZoneSystem;
}

export function HrZoneLegend({ zoneSystem }: HrZoneLegendProps) {
	const isRowing = zoneSystem === 'rowing';
	return (
		<Accordion className="rounded-lg border border-gray-700/50 bg-gray-800/30 px-3">
			<AccordionItem className="border-gray-800">
				<AccordionTrigger className="text-xs font-medium text-gray-300">
					HR zone reference
				</AccordionTrigger>
				<AccordionContent>
					<ul className="space-y-1 pb-2 text-xs">
						{HR_ZONES.map((zone, i) => {
							const zoneNum = i + 1;
							const short = isRowing ? zone.rowingShortLabel : zone.shortLabel;
							const label = isRowing ? zone.rowingLabel : zone.label;
							return (
								<li
									key={zone.name}
									className="grid grid-cols-[12px_2.5rem_1fr_auto] items-center gap-2"
								>
									<span
										className="h-2.5 w-2.5 rounded-full"
										style={{ backgroundColor: HR_ZONE_COLORS[zoneNum] }}
									/>
									<span className="font-semibold text-white">{short}</span>
									<span className="text-gray-400">{label}</span>
									<span className="font-mono text-gray-500">
										{zone.minPct}–{zone.maxPct}% HR
									</span>
								</li>
							);
						})}
					</ul>
				</AccordionContent>
			</AccordionItem>
		</Accordion>
	);
}
