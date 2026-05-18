import type { WorkoutTimeSample } from '@/lib/types';
import { HR_ZONES } from './ftp';

/**
 * Classify a BPM reading into zone 0-5.
 * Uses %HRR (Karvonen) when `restingHr` is known, otherwise %HRmax.
 * Zone thresholds are derived from `HR_ZONES` so they can't drift from the
 * shared definition. Mirrors `apps/mobile/lib/utils/hr_zones.dart::estimateHrZone`.
 */
export function estimateHrZone(
	bpm: number,
	maxHr: number,
	restingHr?: number | null,
): number {
	if (maxHr <= 0 || bpm <= 0) return 0;

	const pct =
		restingHr != null && maxHr > restingHr
			? ((bpm - restingHr) / (maxHr - restingHr)) * 100
			: (bpm / maxHr) * 100;

	// HR_ZONES is ordered Z1..Z5 ascending (same convention as ftp.ts —
	// see `HR_ZONES[zoneNumber - 1]` callers). Reverse-scan to return the
	// highest zone whose `minPct` is met.
	for (let i = HR_ZONES.length - 1; i >= 0; i--) {
		if (pct >= HR_ZONES[i].minPct) return i + 1;
	}
	return 0;
}

/**
 * Time spent in each HR zone (1-5), in seconds, weighted by inter-sample gap.
 * Final sample uses the median of prior gaps so it isn't effectively zero.
 * Returns `{}` when no usable HR data is present.
 *
 * Mirrors `apps/mobile/lib/utils/time_in_zone.dart::timeInZone`.
 */
export function timeInZone(
	samples: WorkoutTimeSample[],
	restingHr: number | null | undefined,
	maxHr: number,
): Record<number, number> {
	if (samples.length === 0 || maxHr <= 0) return {};

	const hrSamples = samples.filter((s) => s.hr != null && s.hr > 0);
	if (hrSamples.length === 0) return {};

	const dts = new Array<number>(hrSamples.length).fill(0);
	for (let i = 0; i < hrSamples.length - 1; i++) {
		const dtMs = hrSamples[i + 1].t - hrSamples[i].t;
		dts[i] = dtMs > 0 ? dtMs / 1000 : 1;
	}
	dts[dts.length - 1] =
		dts.length === 1 ? 1 : median(dts.slice(0, dts.length - 1));

	const result: Record<number, number> = {};
	for (let i = 0; i < hrSamples.length; i++) {
		const zone = estimateHrZone(hrSamples[i].hr!, maxHr, restingHr);
		if (zone < 1 || zone > 5) continue;
		result[zone] = (result[zone] ?? 0) + dts[i];
	}
	return result;
}

/** `{segmentIndex: timeInZone}` from a single O(N) grouping pass. */
export function timeInZoneBySegment(
	samples: WorkoutTimeSample[],
	restingHr: number | null | undefined,
	maxHr: number,
): Record<number, Record<number, number>> {
	const grouped: Record<number, WorkoutTimeSample[]> = {};
	for (const s of samples) {
		(grouped[s.si] ??= []).push(s);
	}
	const out: Record<number, Record<number, number>> = {};
	for (const [k, v] of Object.entries(grouped)) {
		out[Number(k)] = timeInZone(v, restingHr, maxHr);
	}
	return out;
}

function median(xs: number[]): number {
	const sorted = [...xs].sort((a, b) => a - b);
	const n = sorted.length;
	return n % 2 === 1
		? sorted[(n - 1) / 2]
		: (sorted[n / 2 - 1] + sorted[n / 2]) / 2;
}
