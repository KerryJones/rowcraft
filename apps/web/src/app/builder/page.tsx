import { Suspense } from 'react';
import BuilderPage from './builder-client';

export const metadata = { title: 'Workout Builder — RowCraft', description: 'Design custom interval rowing workouts.' };

export default function Page() {
  return (
    <Suspense fallback={
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-gray-700 border-t-blue-500" />
      </div>
    }>
      <BuilderPage />
    </Suspense>
  );
}
