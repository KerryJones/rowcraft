import type { Metadata } from 'next';
import { createSupabaseServer, getUser } from '@/lib/supabase/server';
import type { Workout } from '@/lib/types';
import { normalizeWorkoutSegments } from '@/lib/types';
import { WorkoutsClient } from './workouts-client';
import { JsonLd } from '@/components/json-ld';
import { FaqSection, type FaqItem } from '@/components/faq-section';
import { SITE_URL, buildFaqJsonLd } from '@/lib/seo';

export const metadata: Metadata = {
  title: 'Workouts — RowCraft',
  description: 'Browse structured rowing workouts for Concept2 ergometers.',
  alternates: { canonical: '/workouts' },
};

const workoutFaqs: FaqItem[] = [
  {
    question: 'What types of rowing workouts does RowCraft offer?',
    answer: 'RowCraft includes workouts across all five heart rate training zones: Zone 1 recovery, Zone 2 aerobic (steady state), Zone 3 tempo, Zone 4 threshold, and Zone 5 VO2max (sprint intervals). Workouts range from short 20-minute sessions to 60+ minute endurance pieces.',
  },
  {
    question: 'Can I create my own rowing workouts?',
    answer: 'Yes. The workout builder lets you design custom interval workouts with configurable work and rest segments. You can set target intensity (as a percentage of your FTP), stroke rate targets, and duration for each segment. You can also add coaching cues that display during the workout.',
  },
  {
    question: 'What is FTP-based training?',
    answer: 'FTP (Functional Threshold Power) is the maximum power you can sustain for about 60 minutes. RowCraft uses your FTP to calculate personalized pace targets for every workout segment. A Zone 2 workout at 70% FTP will show a different pace target for a 150-watt rower versus a 250-watt rower.',
  },
];

export default async function WorkoutsPage() {
  const supabase = await createSupabaseServer();
  const user = await getUser();
  const userId = user?.id;

  let query = supabase
    .from('workouts')
    .select('*')
    .order('created_at', { ascending: false });

  if (userId) {
    query = query.or(`is_public.eq.true,author_id.eq.${userId}`);
  } else {
    query = query.eq('is_public', true);
  }

  const { data } = await query;

  const workouts: Workout[] = (data ?? []).map((w) => ({
    ...w,
    segments: normalizeWorkoutSegments(w.segments ?? []),
  }));

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

  const publicWorkouts = workouts.filter((w) => w.is_public);

  return (
    <>
      <JsonLd data={{
        '@context': 'https://schema.org',
        '@type': 'CollectionPage',
        name: 'Rowing Workouts',
        description: 'Browse structured rowing workouts for Concept2 ergometers.',
        url: `${SITE_URL}/workouts`,
        mainEntity: {
          '@type': 'ItemList',
          numberOfItems: publicWorkouts.length,
          itemListElement: publicWorkouts.slice(0, 50).map((w, i) => ({
            '@type': 'ListItem',
            position: i + 1,
            url: `${SITE_URL}/workouts/${w.id}`,
            name: w.title,
          })),
        },
      }} />
      <WorkoutsClient workouts={workouts} userId={userId ?? null} ftpWatts={ftpWatts} />
      <JsonLd data={buildFaqJsonLd(workoutFaqs)} />
      <div className="mx-auto max-w-7xl px-4 pb-16 pt-8 sm:px-6 lg:px-8">
        <FaqSection items={workoutFaqs} />
      </div>
    </>
  );
}
