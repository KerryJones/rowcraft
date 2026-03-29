import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { Workout, WorkoutSegment } from '@/lib/types';
import { normalizeWorkoutSegments } from '@/lib/types';
import { formatWorkoutType } from '@/lib/utils/format';
import { WorkoutGraph } from '@/components/workout-graph';
import { StatsBar } from '@/components/ui/stats-bar';
import { SegmentCard } from '@/components/ui/segment-card';
import { WorkoutDetailActions } from './actions';

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

/** Expand segments: if a segment has repeat > 1, produce N copies */
function expandSegments(segments: WorkoutSegment[]): { segment: WorkoutSegment; label: string }[] {
  const result: { segment: WorkoutSegment; label: string }[] = [];
  let counter = 1;

  for (const seg of segments) {
    const repeat = seg.repeat || 1;
    for (let r = 0; r < repeat; r++) {
      result.push({
        segment: { ...seg, repeat: 1 },
        label: `#${counter}`,
      });
      counter++;
    }
  }

  return result;
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

  const expandedSegments = expandSegments(workout.segments);
  const isOwner = user?.id === workout.author_id;

  return (
    <div className="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      {/* Graph */}
      <div className="mb-6">
        <WorkoutGraph segments={workout.segments} />
      </div>

      {/* Title + badges */}
      <div className="mb-4 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-white">{workout.title}</h1>
          <div className="mt-2 flex items-center gap-2">
            <span className="rounded-full bg-gray-800 px-3 py-1 text-xs font-medium text-gray-400">
              {formatWorkoutType(workout.workout_type)}
            </span>
            {workout.tags.map((tag) => (
              <span
                key={tag}
                className="rounded-full bg-gray-800 px-2 py-0.5 text-xs text-gray-500"
              >
                {tag}
              </span>
            ))}
          </div>
        </div>
        <WorkoutDetailActions workoutId={workout.id} isOwner={isOwner} isLoggedIn={!!user} />
      </div>

      {/* Description */}
      {workout.description && (
        <p className="mb-6 text-gray-400">{workout.description}</p>
      )}

      {/* Stats */}
      <div className="mb-8">
        <StatsBar segments={workout.segments} />
      </div>

      {/* Segments */}
      <h2 className="mb-4 text-lg font-semibold text-white">Segments</h2>
      <div className="space-y-3">
        {expandedSegments.map(({ segment, label }, i) => (
          <SegmentCard key={i} segment={segment} index={i} instanceLabel={label} />
        ))}
      </div>

      {/* CTA */}
      <div className="mt-12 rounded-xl border border-blue-500/30 bg-blue-500/5 p-6 text-center">
        <h3 className="text-lg font-semibold text-white">Ready to row?</h3>
        <p className="mt-1 text-sm text-gray-400">
          Open RowCraft on your phone and connect to your PM5 to start this workout.
        </p>
      </div>
    </div>
  );
}
