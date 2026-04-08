'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createSupabaseBrowser } from '@/lib/supabase/client';
import { Share2, GitFork, Pencil, Trash2 } from 'lucide-react';

interface WorkoutDetailActionsProps {
  workoutId: string;
  isOwner: boolean;
  isLoggedIn: boolean;
}

export function WorkoutDetailActions({ workoutId, isOwner, isLoggedIn }: WorkoutDetailActionsProps) {
  const router = useRouter();
  const [deleteError, setDeleteError] = useState<string | null>(null);

  async function handleShare() {
    try {
      await navigator.clipboard.writeText(window.location.href);
    } catch {
      // Fallback: do nothing
    }
  }

  async function handleFork() {
    const supabase = createSupabaseBrowser();
    const { data: original } = await supabase
      .from('workouts')
      .select('*')
      .eq('id', workoutId)
      .single();

    if (!original) return;

    const { data: user } = await supabase.auth.getUser();
    if (!user.user) return;

    const { data: forked } = await supabase
      .from('workouts')
      .insert({
        title: `${original.title} (fork)`,
        description: original.description,
        workout_type: original.workout_type,
        segments: original.segments,
        tags: original.tags,
        is_public: false,
        author_id: user.user.id,
        forked_from: workoutId,
      })
      .select('id')
      .single();

    if (forked) {
      // Increment fork count
      try {
        await supabase.rpc('increment_fork_count', { workout_id: workoutId });
      } catch {
        // Ignore if RPC doesn't exist
      }
      router.push(`/workouts/${forked.id}`);
    }
  }

  async function handleDelete() {
    if (!confirm('Delete this workout? This cannot be undone.')) return;
    setDeleteError(null);
    const supabase = createSupabaseBrowser();
    const { data: user } = await supabase.auth.getUser();
    if (!user.user) return;
    const { error } = await supabase
      .from('workouts')
      .delete()
      .eq('id', workoutId)
      .eq('author_id', user.user.id);
    if (error) {
      setDeleteError('Failed to delete workout. Please try again.');
      return;
    }
    router.push('/workouts');
  }

  return (
    <div className="flex flex-col items-end gap-2">
      <div className="flex items-center gap-2">
        <button
          onClick={handleShare}
          className="flex cursor-pointer items-center gap-1.5 rounded-lg border border-gray-700 px-3 py-2 text-sm text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
          title="Copy link"
        >
          <Share2 className="h-4 w-4" />
          Share
        </button>

        {isLoggedIn && !isOwner && (
          <button
            onClick={handleFork}
            className="flex cursor-pointer items-center gap-1.5 rounded-lg border border-gray-700 px-3 py-2 text-sm text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
            title="Fork workout"
          >
            <GitFork className="h-4 w-4" />
            Fork
          </button>
        )}

        {isOwner && (
          <>
            <button
              onClick={() => router.push(`/builder?edit=${workoutId}`)}
              className="flex cursor-pointer items-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-500"
            >
              <Pencil className="h-4 w-4" />
              Edit
            </button>
            <button
              onClick={handleDelete}
              className="flex cursor-pointer items-center gap-1.5 rounded-lg border border-red-500/30 px-3 py-2 text-sm text-red-400 transition-colors hover:bg-red-500/10 hover:text-red-300"
              title="Delete workout"
            >
              <Trash2 className="h-4 w-4" />
              Delete
            </button>
          </>
        )}
      </div>
      {deleteError && (
        <p className="text-sm text-red-400">{deleteError}</p>
      )}
    </div>
  );
}
