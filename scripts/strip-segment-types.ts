/**
 * strip-segment-types.ts — Remove type: and hr_zone: from all workout YAML files.
 *
 * Segment type lines look like:  "  - type: work"  (starts the list item)
 * The following field line needs to become the new list item starter.
 *
 * hr_zone lines look like:  "    hr_zone: 1"  (just remove them)
 *
 * type: interval lines are PRESERVED (they are build-time expansion directives).
 *
 * Usage: npx tsx scripts/strip-segment-types.ts
 */

import { readFileSync, writeFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';

const WORKOUTS_DIR = join(import.meta.dirname, '..', 'packages/shared/workouts');

function transformYaml(content: string): string {
  const lines = content.split('\n');
  const result: string[] = [];
  let promoteNextField = false; // next field line should become a list item starter

  for (const line of lines) {
    // Segment type line: "  - type: work|rest|warmup|cooldown" (not interval)
    if (/^\s+-\s+type:\s+(work|rest|warmup|cooldown)\s*$/.test(line)) {
      promoteNextField = true;
      continue; // drop this line
    }

    // HR zone line: "    hr_zone: N"
    if (/^\s+hr_zone:\s+\d+\s*$/.test(line)) {
      continue; // drop this line
    }

    // If we're expecting to promote the next field to a list item
    if (promoteNextField) {
      if (line.trim().length === 0) {
        // Empty line — pass through and keep waiting
        result.push(line);
        continue;
      }
      // Replace leading whitespace with "  - " to make this the list item starter
      // The original field is at 4 spaces (e.g. "    duration:"), becomes "  - duration:"
      const promoted = line.replace(/^(\s{4})/, '  - ');
      result.push(promoted);
      promoteNextField = false;
      continue;
    }

    result.push(line);
  }

  return result.join('\n');
}

function processDir(dir: string): number {
  let count = 0;
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      count += processDir(fullPath);
    } else if (entry.endsWith('.yaml') || entry.endsWith('.yml')) {
      const original = readFileSync(fullPath, 'utf-8');
      const transformed = transformYaml(original);
      if (transformed !== original) {
        writeFileSync(fullPath, transformed, 'utf-8');
        console.log(`  Updated: ${fullPath.replace(process.cwd() + '/', '')}`);
        count++;
      }
    }
  }
  return count;
}

const updated = processDir(WORKOUTS_DIR);
console.log(`\nDone. Updated ${updated} files.`);
