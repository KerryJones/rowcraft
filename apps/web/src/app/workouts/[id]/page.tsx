import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { Workout } from '@/lib/types';
import { normalizeWorkoutSegments } from '@/lib/types';
import { formatWorkoutType, getWorkoutTypeBadgeColor, formatDate, formatSegmentDuration } from '@/lib/utils/format';
import { isRestSegment } from '@/lib/types';
import { WorkoutGraph } from '@/components/workout-graph';
import { StatsBar } from '@/components/ui/stats-bar';
import { SegmentCard } from '@/components/ui/segment-card';
import { WorkoutDetailActions } from './actions';
import { expandSegments } from '@/lib/utils/workout';
import { JsonLd } from '@/components/json-ld';
import { SITE_URL, ROWCRAFT_ORGANIZATION } from '@/lib/seo';

interface PageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { id } = await params;
  const supabase = await createSupabaseServer();
  const { data } = await supabase.from('workouts').select('title, description').eq('id', id).eq('is_public', true).single();

  if (!data) return { title: 'Workout Not Found — RowCraft' };

  return {
    title: `${data.title} — RowCraft`,
    description: data.description || 'A RowCraft workout',
    alternates: { canonical: `/workouts/${id}` },
    openGraph: {
      title: data.title,
      description: data.description || 'A RowCraft workout',
      type: 'article',
    },
  };
}



export default async function WorkoutDetailPage({ params }: PageProps) {
  const { id } = await params;
  const supabase = await createSupabaseServer();
  const user = await getUser();

  const userId = user?.id;
  let query = supabase.from('workouts').select('*').eq('id', id);
  if (userId) {
    query = query.or(`is_public.eq.true,author_id.eq.${userId}`);
  } else {
    query = query.eq('is_public', true);
  }
  const { data } = await query.single();

  if (!data) notFound();

  const workout: Workout = {
    ...data,
    segments: normalizeWorkoutSegments(data.segments ?? []),
  };

  const expanded = expandSegments(workout.segments);
  const isOwner = user?.id === workout.author_id;

  // Fetch user's FTP for pace display
  let ftpWatts: number | null = null;
  if (userId) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('current_ftp_watts')
      .eq('id', userId)
      .single();
    ftpWatts = profile?.current_ftp_watts ?? null;
  }

  // Collect coaching cues — one entry per segment
  const coachingCues: { segmentLabel: string; text: string }[] = [];
  for (let i = 0; i < expanded.length; i++) {
    const seg = expanded[i];
    if (seg.messages) {
      const zoneLabel = isRestSegment(seg) ? 'REST' : seg.target_hr_zone != null ? `Z${seg.target_hr_zone}` : 'Active';
      const label = `#${i + 1} ${zoneLabel}`;
      for (const msg of seg.messages) {
        coachingCues.push({ segmentLabel: label, text: msg.text });
      }
    }
  }

  // Build workload description for JSON-LD and citable summary
  const totalSeconds = expanded.reduce((sum, seg) => {
    if (seg.duration_type === 'time') return sum + seg.duration_value;
    return sum;
  }, 0);
  const totalMinutes = Math.round(totalSeconds / 60);

  const zoneCounts = new Map<number, number>();
  for (const s of expanded) {
    if (!isRestSegment(s) && s.target_hr_zone != null) {
      zoneCounts.set(s.target_hr_zone, (zoneCounts.get(s.target_hr_zone) ?? 0) + 1);
    }
  }
  let dominantZone: number | null = null;
  let maxCount = 0;
  for (const [zone, count] of zoneCounts) {
    if (count > maxCount) { dominantZone = zone; maxCount = count; }
  }

  const workSegments = expanded.filter((s) => s.target_intensity != null && !isRestSegment(s));
  const intensities = workSegments.map((s) => s.target_intensity!);

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      <JsonLd data={{
        '@context': 'https://schema.org',
        '@type': 'ExercisePlan',
        name: workout.title,
        description: workout.description || `A ${formatWorkoutType(workout.workout_type).toLowerCase()} rowing workout for Concept2 ergometers.`,
        url: `${SITE_URL}/workouts/${workout.id}`,
        exerciseType: 'Rowing',
        provider: ROWCRAFT_ORGANIZATION,
        ...(totalMinutes > 0 && { workload: `${expanded.length} segments, approximately ${totalMinutes} minutes` }),
        ...(dominantZone != null && { intensity: `Heart rate zone ${dominantZone}` }),
      }} />
      {/* Hero graph */}
      <div className="mb-6">
        <WorkoutGraph segments={workout.segments} variant="hero" ftpWatts={ftpWatts} />
      </div>

      {/* Title + actions row */}
      <div className="mb-4 flex flex-wrap items-start justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className={`rounded-full px-3 py-1 text-xs font-medium ${getWorkoutTypeBadgeColor(workout.workout_type)}`}>
            {formatWorkoutType(workout.workout_type)}
          </span>
          <h1 className="text-3xl font-bold text-white">{workout.title}</h1>
        </div>
        <WorkoutDetailActions workoutId={workout.id} isOwner={isOwner} isLoggedIn={!!user} />
      </div>

      {/* Description */}
      {workout.description && (
        <p className="mb-4 text-gray-400">{workout.description}</p>
      )}

      {/* AI-citable summary */}
      <p className="mb-4 text-sm text-gray-500">
        {`This ${formatWorkoutType(workout.workout_type).toLowerCase()} rowing workout consists of ${expanded.length} segment${expanded.length !== 1 ? 's' : ''}`}
        {totalMinutes > 0 && ` totaling approximately ${totalMinutes} minute${totalMinutes !== 1 ? 's' : ''}`}
        {dominantZone != null && `, primarily targeting heart rate zone ${dominantZone}`}
        {'. '}
        {intensities.length > 0 &&
          `Intensity ranges from ${Math.min(...intensities)}% to ${Math.max(...intensities)}% of FTP. `}
        {'Designed for use on a Concept2 ergometer with PM5 Bluetooth connectivity.'}
      </p>

      {/* Tags + metadata row */}
      <div className="mb-8 flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap gap-1.5">
          {workout.tags.map((tag) => (
            <span
              key={tag}
              className="rounded-full bg-gray-800 px-2.5 py-0.5 text-xs text-gray-400"
            >
              {tag}
            </span>
          ))}
        </div>
        <span className="text-xs text-gray-500">
          {formatDate(workout.created_at)}
        </span>
      </div>

      {/* Stats boxes */}
      <div className="mb-8">
        <StatsBar segments={workout.segments} forkCount={workout.fork_count} ftpWatts={ftpWatts} />
      </div>

      {/* Segments */}
      <h2 className="mb-4 text-lg font-semibold text-white">Segments</h2>
      <div className="mb-8 space-y-3">
        {expanded.map((seg, i) => (
          <SegmentCard
            key={i}
            segment={seg}
            index={i}
            ftpWatts={ftpWatts}
          />
        ))}
      </div>

      {/* Coaching cues */}
      {coachingCues.length > 0 && (
        <div className="mb-8">
          <h2 className="mb-4 text-lg font-semibold text-white">Coaching Cues</h2>
          <div className="space-y-2">
            {coachingCues.map((cue, i) => (
              <div key={i} className="rounded-lg border border-gray-800 bg-gray-900 p-3">
                <span className="text-xs font-medium text-gray-500">{cue.segmentLabel}</span>
                <p className="mt-0.5 text-sm italic text-gray-400">&ldquo;{cue.text}&rdquo;</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* CTA */}
      <div className="rounded-xl border border-blue-500/30 bg-blue-500/5 p-6 text-center">
        <h3 className="text-lg font-semibold text-white">Ready to row?</h3>
        <p className="mt-1 text-sm text-gray-400">
          Open RowCraft on your phone and connect to your rower to start this workout.
        </p>
      </div>
    </div>
  );
}
