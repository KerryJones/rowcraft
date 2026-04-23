/**
 * build-seeds.ts — Convert YAML workout definitions to SQL seed files.
 *
 * Usage: npx tsx build-seeds.ts
 *
 * Reads:   packages/shared/workouts/**\/*.yaml
 * Schema:  packages/shared/schemas/workout-definition.schema.json
 * Writes:  supabase/seeds/generated/*.sql
 */

import { readFileSync, writeFileSync, readdirSync, statSync, mkdirSync, rmSync } from 'fs';
import { join, relative, dirname, basename } from 'path';
import yaml from 'js-yaml';
import Ajv from 'ajv';

const ROOT = join(import.meta.dirname, '..');
const WORKOUTS_DIR = join(ROOT, 'packages/shared/workouts');
const SCHEMA_PATH = join(ROOT, 'packages/shared/schemas/workout-definition.schema.json');
const OUTPUT_DIR = join(ROOT, 'supabase/seeds');

// ── Types ───────────────────────────────────────────────────────────────────

interface YamlMessage {
  at: string;
  text: string;
}

interface YamlTargetFields {
  duration: string;
  intensity?: string;
  target_watts?: number;
  stroke_rate?: number;
  messages?: YamlMessage[];
}

interface YamlFlatSegment {
  duration: string;
  intensity?: string;
  target_watts?: number;
  stroke_rate?: number;
  messages?: YamlMessage[];
}

interface YamlIntervalSegment {
  type: 'interval';
  reps: number;
  work: YamlTargetFields;
  rest?: { duration: string };
}

type YamlSegment = YamlFlatSegment | YamlIntervalSegment;

interface YamlWorkout {
  id: string;
  title: string;
  description: string;
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  tags: string[];
  segments: YamlSegment[];
}

interface DbSegment {
  duration_type: string;
  duration_value: number;
  target_intensity: number | null;
  target_watts: number | null;
  target_stroke_rate: number | null;
  target_hr_zone: number | null;
  is_rest?: boolean;
  messages?: DbMessage[] | null;
}

interface DbMessage {
  trigger_type: 'time' | 'distance' | 'start' | 'end';
  trigger_value: number;
  text: string;
}

// ── HR Zone Derivation ───────────────────────────────────────────────────────

/**
 * Derive HR zone (1-5) from intensity % of FTP.
 * Boundaries match the HR_ZONES definition in apps/web/src/lib/utils/ftp.ts.
 */
function intensityToHrZone(intensityPct: number): number {
  if (intensityPct < 60) return 1;   // recovery
  if (intensityPct < 75) return 2;   // aerobic
  if (intensityPct < 85) return 3;   // tempo
  if (intensityPct < 92) return 4;   // threshold
  return 5;                           // max / VO2max
}

// ── Parsers ─────────────────────────────────────────────────────────────────

function parseDuration(raw: string): { type: 'time' | 'distance' | 'calories'; value: number } {
  // Distance: 500m
  const distMatch = raw.match(/^(\d+)m$/);
  if (distMatch) return { type: 'distance', value: parseInt(distMatch[1]) };

  // Calories: 100cal
  const calMatch = raw.match(/^(\d+)cal$/);
  if (calMatch) return { type: 'calories', value: parseInt(calMatch[1]) };

  // Time: M:SS
  const timeMatch = raw.match(/^(\d{1,3}):(\d{2})$/);
  if (timeMatch) {
    const mins = parseInt(timeMatch[1]);
    const secs = parseInt(timeMatch[2]);
    if (secs >= 60) throw new Error(`Invalid seconds in duration: ${raw}`);
    return { type: 'time', value: mins * 60 + secs };
  }

  // Bare seconds: 30
  const bareMatch = raw.match(/^(\d+)$/);
  if (bareMatch) return { type: 'time', value: parseInt(bareMatch[1]) };

  throw new Error(`Cannot parse duration: ${raw}`);
}

function parseIntensity(raw: string): number {
  const match = raw.match(/^(\d{1,3})%$/);
  if (!match) throw new Error(`Cannot parse intensity: ${raw} (expected format: N%)`);
  const value = parseInt(match[1]);
  if (value > 200) throw new Error(`Intensity exceeds 200%: ${raw}`);
  return value;
}

function parseStrokeRate(raw: number): number {
  if (!Number.isInteger(raw)) throw new Error(`Stroke rate must be an integer: ${raw}`);
  if (raw < 10 || raw > 50) throw new Error(`Stroke rate out of range 10-50: ${raw}`);
  return raw;
}

function parseMessageTrigger(at: string): { trigger_type: DbMessage['trigger_type']; trigger_value: number } {
  if (at === 'start') return { trigger_type: 'start', trigger_value: 0 };
  if (at === 'end') return { trigger_type: 'end', trigger_value: 0 };

  const distMatch = at.match(/^(\d+)m$/);
  if (distMatch) return { trigger_type: 'distance', trigger_value: parseInt(distMatch[1]) };

  const timeMatch = at.match(/^(\d{1,3}):(\d{2})$/);
  if (timeMatch) {
    return { trigger_type: 'time', trigger_value: parseInt(timeMatch[1]) * 60 + parseInt(timeMatch[2]) };
  }

  throw new Error(`Cannot parse message trigger: ${at}`);
}

// ── Segment Expansion ───────────────────────────────────────────────────────

function buildDbSegment(fields: YamlTargetFields): DbSegment {
  const dur = parseDuration(fields.duration);
  const targetIntensity = fields.intensity != null ? parseIntensity(fields.intensity) : null;
  const targetWatts = fields.target_watts ?? null;
  const seg: DbSegment = {
    duration_type: dur.type,
    duration_value: dur.value,
    target_intensity: targetIntensity,
    target_watts: targetWatts,
    target_stroke_rate: fields.stroke_rate != null ? parseStrokeRate(fields.stroke_rate) : null,
    target_hr_zone: targetIntensity != null ? intensityToHrZone(targetIntensity) : null,
  };
  if (fields.messages && fields.messages.length > 0) {
    seg.messages = fields.messages.map((m) => ({
      ...parseMessageTrigger(m.at),
      text: m.text,
    }));
  }
  return seg;
}

function isIntervalSegment(seg: YamlSegment): seg is YamlIntervalSegment {
  return (seg as YamlIntervalSegment).type === 'interval';
}

function expandSegments(yamlSegments: YamlSegment[]): DbSegment[] {
  const result: DbSegment[] = [];

  for (const seg of yamlSegments) {
    if (isIntervalSegment(seg)) {
      if (!seg.reps || !seg.work) throw new Error('interval segment requires reps and work');
      const workSeg = buildDbSegment(seg.work);
      const restSeg = seg.rest ? { ...buildDbSegment({ duration: seg.rest.duration }), is_rest: true } : null;

      for (let i = 0; i < seg.reps; i++) {
        result.push({ ...workSeg });
        // Rest after every rep except the last
        if (restSeg && i < seg.reps - 1) {
          result.push({ ...restSeg });
        }
      }
    } else {
      result.push(buildDbSegment(seg as YamlTargetFields));
    }
  }

  return result;
}

// ── Workout Type Inference ──────────────────────────────────────────────────

function inferWorkoutType(segments: DbSegment[]): string {
  // Active segments are those with a pace target (intensity% or absolute watts)
  const activeSegs = segments.filter((s) => s.target_intensity != null || s.target_watts != null);

  if (activeSegs.length === 0) return 'single_time';

  // Single active segment (ignoring rest segments)
  if (activeSegs.length === 1) {
    return activeSegs[0].duration_type === 'distance' ? 'single_distance' : 'single_time';
  }

  // Check if all active segments are identical (intervals pattern)
  const isActive = (s: DbSegment) => s.target_intensity != null || s.target_watts != null;

  const allIdentical = activeSegs.every((s) =>
    s.duration_type === activeSegs[0].duration_type &&
    s.duration_value === activeSegs[0].duration_value &&
    s.target_intensity === activeSegs[0].target_intensity &&
    s.target_watts === activeSegs[0].target_watts &&
    s.target_stroke_rate === activeSegs[0].target_stroke_rate &&
    s.target_hr_zone === activeSegs[0].target_hr_zone
  );

  // Pure intervals: all active segments identical, no leading/trailing non-identical active segs
  const hasLeadingRest = !isActive(segments[0]) && segments[0]?.target_stroke_rate == null;
  const hasTrailingRest = !isActive(segments[segments.length - 1]) && segments[segments.length - 1]?.target_stroke_rate == null;

  if (allIdentical && !hasLeadingRest && !hasTrailingRest) {
    return 'intervals';
  }

  return 'variable_intervals';
}

// ── SQL Generation ──────────────────────────────────────────────────────────

function escapeSQL(str: string): string {
  return str.replace(/'/g, "''");
}

function workoutToSQL(workout: YamlWorkout): string {
  const segments = expandSegments(workout.segments);
  const workoutType = inferWorkoutType(segments);
  const segmentsJson = JSON.stringify(segments);
  // Validate tags contain only safe characters (lowercase, digits, hyphens)
  for (const tag of workout.tags) {
    if (!/^[a-z0-9-]+$/.test(tag)) {
      throw new Error(`Invalid tag "${tag}" in workout "${workout.title}" — tags must be lowercase alphanumeric with hyphens only`);
    }
  }
  const tags = `'{${workout.tags.join(',')}}'`;

  return [
    `insert into public.workouts (id, title, description, workout_type, segments, tags, is_public) values (`,
    `  '${workout.id}',`,
    `  '${escapeSQL(workout.title)}',`,
    `  '${escapeSQL(workout.description)}',`,
    `  '${workoutType}',`,
    `  '${escapeSQL(segmentsJson)}'::jsonb,`,
    `  ${tags},`,
    `  true`,
    `);`,
  ].join('\n');
}

// ── File Discovery ──────────────────────────────────────────────────────────

function findYamlFiles(dir: string): string[] {
  const files: string[] = [];
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      files.push(...findYamlFiles(fullPath));
    } else if (entry.endsWith('.yaml') || entry.endsWith('.yml')) {
      files.push(fullPath);
    }
  }
  return files.sort();
}

function getCategoryFromPath(filePath: string): string {
  const rel = relative(WORKOUTS_DIR, filePath);
  const dir = dirname(rel);
  return dir === '.' ? 'uncategorized' : dir;
}

// ── Main ────────────────────────────────────────────────────────────────────

function main() {
  // Load and compile schema
  const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf-8'));
  const ajv = new Ajv({ allErrors: true });
  const validate = ajv.compile(schema);

  // Find all YAML files
  const yamlFiles = findYamlFiles(WORKOUTS_DIR);
  if (yamlFiles.length === 0) {
    console.error('No YAML files found in', WORKOUTS_DIR);
    process.exit(1);
  }

  console.log(`Found ${yamlFiles.length} workout files`);

  // Parse and validate
  const workoutsByCategory = new Map<string, { workout: YamlWorkout; sql: string }[]>();
  const seenIds = new Set<string>();
  let errors = 0;

  for (const filePath of yamlFiles) {
    const relPath = relative(ROOT, filePath);
    try {
      const raw = readFileSync(filePath, 'utf-8');
      const data = yaml.load(raw) as YamlWorkout;

      // Schema validation
      const valid = validate(data);
      if (!valid) {
        console.error(`SCHEMA ERROR in ${relPath}:`);
        for (const err of validate.errors ?? []) {
          console.error(`  ${err.instancePath || '/'}: ${err.message}`);
        }
        errors++;
        continue;
      }

      // Duplicate ID check
      if (seenIds.has(data.id)) {
        console.error(`DUPLICATE ID in ${relPath}: ${data.id}`);
        errors++;
        continue;
      }
      seenIds.add(data.id);

      // Generate SQL
      const sql = workoutToSQL(data);
      const category = getCategoryFromPath(filePath);

      if (!workoutsByCategory.has(category)) {
        workoutsByCategory.set(category, []);
      }
      workoutsByCategory.get(category)!.push({ workout: data, sql });

    } catch (err) {
      console.error(`ERROR in ${relPath}: ${(err as Error).message}`);
      errors++;
    }
  }

  if (errors > 0) {
    console.error(`\n${errors} error(s) found. Fix them before generating SQL.`);
    process.exit(1);
  }

  // Write output files
  mkdirSync(OUTPUT_DIR, { recursive: true });

  // Remove old generated files (keep non-generated ones like 90_training_plans.sql)
  for (const f of readdirSync(OUTPUT_DIR)) {
    if (f.startsWith('gen_')) {
      rmSync(join(OUTPUT_DIR, f));
    }
  }

  // Write per-category SQL files
  const allSql: string[] = [];
  allSql.push('-- Generated by scripts/build-seeds.ts — do not edit manually');
  allSql.push('-- Wipe all system workouts (author_id IS NULL) then re-insert');
  allSql.push('delete from public.workouts where author_id is null;\n');

  const sortedCategories = [...workoutsByCategory.keys()].sort();
  for (const category of sortedCategories) {
    const items = workoutsByCategory.get(category)!;
    const fileName = `gen_${category.replace(/\//g, '_')}.sql`;
    const header = `-- ${category} (${items.length} workouts)\n-- Generated by scripts/build-seeds.ts — do not edit manually\n`;
    const body = items.map((i) => i.sql).join('\n\n');
    const content = header + '\n' + body + '\n';

    writeFileSync(join(OUTPUT_DIR, fileName), content);
    allSql.push(`-- ${category} (${items.length})`);
    allSql.push(body);
    allSql.push('');

    console.log(`  ${fileName}: ${items.length} workouts`);
  }

  // Write combined file
  writeFileSync(join(OUTPUT_DIR, 'gen_all_workouts.sql'), allSql.join('\n') + '\n');

  const totalWorkouts = [...workoutsByCategory.values()].reduce((a, b) => a + b.length, 0);
  console.log(`\nGenerated ${totalWorkouts} workouts across ${sortedCategories.length} categories`);
  console.log(`Output: ${OUTPUT_DIR}/gen_*.sql`);
}

main();
