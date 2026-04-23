import { createSupabaseServer } from '@/lib/supabase/server';
import { SITE_URL } from '@/lib/seo';

export const revalidate = 3600;

export async function GET() {
  const supabase = await createSupabaseServer();

  const [{ data: workouts }, { data: plans }] = await Promise.all([
    supabase
      .from('workouts')
      .select('id, title, description, workout_type, tags, created_at')
      .eq('is_public', true)
      .order('title'),
    supabase
      .from('training_plans')
      .select('slug, title, description, difficulty, duration_weeks, sessions_per_week, tags')
      .eq('is_active', true)
      .order('title'),
  ]);

  const lines: string[] = [
    '# RowCraft — Full Content Listing',
    '',
    '> Complete listing of all public workouts and training plans available on RowCraft,',
    '> a free rowing workout platform for Concept2 ergometers.',
    '',
    '## Training Plans',
    '',
  ];

  if (plans && plans.length > 0) {
    for (const plan of plans) {
      lines.push(`### ${plan.title}`);
      lines.push(`- URL: ${SITE_URL}/plans/${plan.slug}`);
      lines.push(`- Difficulty: ${plan.difficulty}`);
      lines.push(`- Duration: ${plan.duration_weeks} weeks, ${plan.sessions_per_week} sessions/week`);
      if (plan.tags.length > 0) lines.push(`- Tags: ${plan.tags.join(', ')}`);
      if (plan.description) lines.push(`- Description: ${plan.description}`);
      lines.push('');
    }
  }

  lines.push('## Workouts', '');

  // Group workouts by first matching category tag (each workout appears once)
  const categoryOrder = [
    'zone1', 'zone2', 'zone3', 'zone4', 'zone5',
    'pete-plan', 'wolverine', 'british-rowing', 'return-to-rowing',
    'ftp', 'test', '2k',
  ];

  const categoryLabels: Record<string, string> = {
    zone1: 'Zone 1 — Recovery',
    zone2: 'Zone 2 — Aerobic / Steady State',
    zone3: 'Zone 3 — Tempo',
    zone4: 'Zone 4 — Threshold',
    zone5: 'Zone 5 — VO2max / Sprint',
    'pete-plan': 'Pete Plan',
    wolverine: 'Wolverine Plan',
    'british-rowing': 'British Rowing',
    'return-to-rowing': 'Return to Rowing',
    ftp: 'FTP Testing',
    test: 'Benchmark Tests',
    '2k': '2K Race Prep',
    other: 'Other Workouts',
  };

  const buckets = new Map<string, NonNullable<typeof workouts>>();
  for (const cat of categoryOrder) buckets.set(cat, []);
  buckets.set('other', []);

  if (workouts) {
    for (const w of workouts) {
      const cat = categoryOrder.find((c) => w.tags.includes(c)) ?? 'other';
      buckets.get(cat)!.push(w);
    }
  }

  for (const [cat, catWorkouts] of buckets) {
    if (catWorkouts.length === 0) continue;
    lines.push(`### ${categoryLabels[cat] ?? cat}`, '');
    for (const w of catWorkouts) {
      lines.push(`- **${w.title}** — ${w.description || 'No description'}`);
      lines.push(`  URL: ${SITE_URL}/workouts/${w.id}`);
    }
    lines.push('');
  }

  lines.push(
    '---',
    '',
    `For more information, visit ${SITE_URL}`,
    'Contact: support@rowcraft.app',
  );

  return new Response(lines.join('\n'), {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
