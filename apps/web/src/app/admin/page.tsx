import {
  getOverviewStats,
  getActiveUsers7d,
  getTotalMeters,
  getRecentSessions,
  getPopularWorkouts,
} from '@/lib/admin-queries';
import { formatDistance, formatDuration, formatDate } from '@/lib/utils/format';

export const dynamic = 'force-dynamic';

export default async function AdminPage() {
  const [stats, activeUsers7d, totalMeters, recentSessions, popularWorkouts] =
    await Promise.all([
      getOverviewStats(),
      getActiveUsers7d(),
      getTotalMeters(),
      getRecentSessions(),
      getPopularWorkouts(),
    ]);

  return (
    <div className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
      <h1 className="mb-8 text-3xl font-bold text-white">Admin Dashboard</h1>

      {/* Stat cards */}
      <div className="mb-12 grid grid-cols-2 gap-4 lg:grid-cols-5">
        <StatCard label="Total Users" value={stats.totalUsers} />
        <StatCard label="Active (7d)" value={activeUsers7d} />
        <StatCard label="Sessions" value={stats.totalSessions} />
        <StatCard label="Total Meters" value={formatDistance(totalMeters)} />
        <StatCard label="Workouts Created" value={stats.totalWorkouts} />
      </div>

      {/* Tables */}
      <div className="grid gap-8 lg:grid-cols-2">
        {/* Recent Sessions */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-white">Recent Sessions</h2>
          <div className="overflow-hidden rounded-xl border border-gray-700 bg-gray-900">
            <table className="w-full">
              <thead>
                <tr className="bg-gray-800/50 text-left text-xs font-medium uppercase tracking-wider text-gray-400">
                  <th className="px-4 py-3">Date</th>
                  <th className="px-4 py-3">User</th>
                  <th className="px-4 py-3">Workout</th>
                  <th className="px-4 py-3 text-right">Distance</th>
                  <th className="px-4 py-3 text-right">Time</th>
                </tr>
              </thead>
              <tbody>
                {recentSessions.map((session) => (
                  <tr key={session.id} className="border-t border-gray-800 text-sm text-gray-300">
                    <td className="whitespace-nowrap px-4 py-3 text-gray-400">
                      {formatDate(session.startedAt)}
                    </td>
                    <td className="px-4 py-3">{session.userName}</td>
                    <td className="max-w-[200px] truncate px-4 py-3">{session.workoutTitle}</td>
                    <td className="px-4 py-3 text-right font-mono text-gray-200">
                      {formatDistance(session.totalDistance)}
                    </td>
                    <td className="px-4 py-3 text-right font-mono text-gray-200">
                      {formatDuration(Math.round(session.totalTime / 10))}
                    </td>
                  </tr>
                ))}
                {recentSessions.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-sm text-gray-500">
                      No sessions yet
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>

        {/* Popular Workouts */}
        <section>
          <h2 className="mb-4 text-lg font-semibold text-white">Popular Workouts</h2>
          <div className="overflow-hidden rounded-xl border border-gray-700 bg-gray-900">
            <table className="w-full">
              <thead>
                <tr className="bg-gray-800/50 text-left text-xs font-medium uppercase tracking-wider text-gray-400">
                  <th className="px-4 py-3">Title</th>
                  <th className="px-4 py-3">Author</th>
                  <th className="px-4 py-3 text-right">Forks</th>
                </tr>
              </thead>
              <tbody>
                {popularWorkouts.map((workout) => (
                  <tr key={workout.id} className="border-t border-gray-800 text-sm text-gray-300">
                    <td className="max-w-[250px] truncate px-4 py-3">{workout.title}</td>
                    <td className="px-4 py-3 text-gray-400">{workout.authorName}</td>
                    <td className="px-4 py-3 text-right font-mono text-gray-200">
                      {workout.forkCount}
                    </td>
                  </tr>
                ))}
                {popularWorkouts.length === 0 && (
                  <tr>
                    <td colSpan={3} className="px-4 py-8 text-center text-sm text-gray-500">
                      No workouts yet
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="rounded-xl border border-gray-700 bg-gray-900 p-6">
      <p className="text-3xl font-bold text-white">
        {typeof value === 'number' ? value.toLocaleString('en-US') : value}
      </p>
      <p className="mt-1 text-sm text-gray-400">{label}</p>
    </div>
  );
}
