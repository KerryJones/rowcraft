import { Suspense } from 'react';
import PlanBuilderPage from './plan-builder-client';

export const metadata = { title: 'Plan Builder — RowCraft' };

export default function Page() {
  return (
    <Suspense fallback={
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-gray-700 border-t-blue-500" />
      </div>
    }>
      <PlanBuilderPage />
    </Suspense>
  );
}
