import type { Metadata } from 'next';
import { getUser } from '@/lib/supabase/server';
import { DeleteAccountForm } from './delete-form';

export const metadata: Metadata = {
  title: 'Delete Account — RowCraft',
};

export default async function DeleteAccountPage() {
  const user = await getUser();

  return (
    <div className="mx-auto max-w-3xl px-4 py-12 sm:px-6">
      <h1 className="mb-8 text-3xl font-bold text-white">Delete Account</h1>

      <div className="space-y-6 text-sm leading-relaxed text-gray-300">
        <section>
          <h2 className="text-lg font-semibold text-white">What happens when you delete your account</h2>
          <p className="mt-2">
            Deleting your account is <strong className="text-white">permanent and irreversible</strong>. The following
            data will be permanently deleted:
          </p>
          <ul className="mt-3 list-disc space-y-1 pl-5">
            <li>Your account and profile information</li>
            <li>All workout results and history</li>
            <li>FTP test records</li>
            <li>Training plan progress</li>
            <li>Concept2 Logbook connection</li>
          </ul>
          <p className="mt-3">
            Public workouts you created will be preserved but will no longer be associated with your account.
          </p>
        </section>

        <section>
          <h2 className="text-lg font-semibold text-white">Before you delete</h2>
          <ul className="mt-2 list-disc space-y-1 pl-5">
            <li>Export any workout data you want to keep.</li>
            <li>Disconnect your Concept2 Logbook if linked.</li>
            <li>This action cannot be undone &mdash; there is no recovery process.</li>
          </ul>
        </section>

        {user ? (
          <section className="mt-8 rounded-lg border border-red-900/50 bg-red-950/20 p-6">
            <h2 className="text-lg font-semibold text-red-400">Delete your account</h2>
            <p className="mt-2 text-gray-400">
              Signed in as <strong className="text-gray-300">{user.email}</strong>. To confirm
              deletion, type <strong className="text-white">delete all my data</strong> below.
            </p>
            <DeleteAccountForm />
          </section>
        ) : (
          <section className="mt-8 rounded-lg border border-gray-800 bg-gray-900/50 p-6">
            <p className="text-gray-400">
              You must be signed in to delete your account. Sign in from the app or{' '}
              <a href="/auth/login" className="text-blue-400 hover:text-blue-300">sign in on the web</a>,
              then return to this page.
            </p>
            <p className="mt-3 text-gray-400">
              You can also request account deletion by emailing{' '}
              <a href="mailto:support@rowcraft.app" className="text-blue-400 hover:text-blue-300">
                support@rowcraft.app
              </a>.
            </p>
          </section>
        )}
      </div>
    </div>
  );
}
