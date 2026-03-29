import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { Workout } from '@/lib/types';
import { normalizeWorkoutSegments } from '@/lib/types';
import { formatWorkoutType, getWorkoutTypeBadgeColor, formatDate, formatSegmentDuration, formatSegmentType } from '@/lib/utils/format';
import { WorkoutGraph } from '@/components/workout-graph';
import { StatsBar } from '@/components/ui/stats-bar';
import { SegmentCard } from '@/components/ui/segment-card';
import { WorkoutDetailActions } from './actions';
import { groupSegments } from '@/lib/utils/workout';

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

  const grouped = groupSegments(workout.segments);
  const isOwner = user?.id === workout.author_id;

  // Collect coaching cues — one entry per group, not per repeat
  const coachingCues: { segmentLabel: string; text: string }[] = [];
  for (let i = 0; i < grouped.length; i++) {
    const group = grouped[i];
    if (group.segment.messages) {
      const label = group.count > 1
        ? `${group.count} × ${formatSegmentDuration(group.segment)} ${formatSegmentType(group.segment.type)}`
        : `#${i + 1} ${formatSegmentType(group.segment.type)}`;
      for (const msg of group.segment.messages) {
        coachingCues.push({ segmentLabel: label, text: msg.text });
      }
    }
  }

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      {/* Hero graph */}
      <div className="mb-6">
        <WorkoutGraph segments={workout.segments} variant="hero" />
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
        <StatsBar segments={workout.segments} forkCount={workout.fork_count} />
      </div>

      {/* Segments */}
      <h2 className="mb-4 text-lg font-semibold text-white">Segments</h2>
      <div className="mb-8 space-y-3">
        {grouped.map((group, i) => (
          <SegmentCard
            key={i}
            segment={group.segment}
            count={group.count}
            index={i}
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
          Open RowCraft on your phone and connect to your PM5 to start this workout.
        </p>
      </div>
    </div>
  );
}
