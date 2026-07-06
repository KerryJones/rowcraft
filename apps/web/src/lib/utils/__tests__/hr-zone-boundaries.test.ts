// Guards the web zone constants against drift from the single source of
// truth in packages/shared/hr-zones.json. ftp.ts keeps a literal copy so the
// bundle never imports outside the app root — this test is what makes that
// copy safe.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { HR_ZONE_BOUNDARIES, HR_ZONES, intensityToHrZone } from '../ftp';

const sharedPath = join(
	import.meta.dirname,
	'../../../../../../packages/shared/hr-zones.json',
);
const shared = JSON.parse(readFileSync(sharedPath, 'utf-8')) as {
	boundaries: number[];
};

describe('HR zone boundaries single source', () => {
	it('ftp.ts boundaries match packages/shared/hr-zones.json', () => {
		expect([...HR_ZONE_BOUNDARIES]).toEqual(shared.boundaries);
	});

	it('HR_ZONES min/max chain is built from the boundaries', () => {
		expect(HR_ZONES).toHaveLength(shared.boundaries.length);
		HR_ZONES.forEach((zone, i) => {
			expect(zone.minPct).toBe(shared.boundaries[i]);
			expect(zone.maxPct).toBe(shared.boundaries[i + 1] ?? 100);
		});
	});

	it('intensityToHrZone follows the shared boundaries', () => {
		const [first] = shared.boundaries;
		expect(intensityToHrZone(first - 1)).toBeNull();
		shared.boundaries.forEach((boundary, i) => {
			expect(intensityToHrZone(boundary)).toBe(i + 1);
		});
	});
});
