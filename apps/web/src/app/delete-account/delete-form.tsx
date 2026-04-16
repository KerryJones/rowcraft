'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createSupabaseBrowser } from '@/lib/supabase/client';
import { Loader2, Trash2 } from 'lucide-react';

const CONFIRMATION_PHRASE = 'delete all my data';

export function DeleteAccountForm() {
  const router = useRouter();
  const [confirmation, setConfirmation] = useState('');
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isConfirmed = confirmation.toLowerCase().trim() === CONFIRMATION_PHRASE;

  async function handleDelete() {
    if (!isConfirmed || deleting) return;
    setDeleting(true);
    setError(null);

    const supabase = createSupabaseBrowser();
    const { error: rpcError } = await supabase.rpc('delete_user_account');

    if (rpcError) {
      setError(rpcError.message);
      setDeleting(false);
      return;
    }

    await supabase.auth.signOut();
    router.refresh();
    router.push('/');
  }

  return (
    <div className="mt-4 space-y-4">
      <input
        type="text"
        value={confirmation}
        onChange={(e) => setConfirmation(e.target.value)}
        placeholder="Type &quot;delete all my data&quot; to confirm"
        className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-red-500 focus:outline-none"
        disabled={deleting}
      />

      {error && (
        <div className="rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-400">
          {error}
        </div>
      )}

      <button
        type="button"
        onClick={handleDelete}
        disabled={!isConfirmed || deleting}
        className="flex w-full cursor-pointer items-center justify-center gap-2 rounded-lg bg-red-600 px-4 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-red-500 disabled:cursor-not-allowed disabled:opacity-40"
      >
        {deleting ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          <Trash2 className="h-4 w-4" />
        )}
        {deleting ? 'Deleting...' : 'Delete My Account'}
      </button>
    </div>
  );
}
