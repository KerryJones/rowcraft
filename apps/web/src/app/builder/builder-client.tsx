'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createSupabaseBrowser } from '@/lib/supabase/client';
import type { Workout, WorkoutSegment, WorkoutType, SegmentType, Profile } from '@/lib/types';
import { normalizeWorkoutSegments } from '@/lib/types';
import { wattsToPaceTenths } from '@/lib/utils/ftp';
import { WorkoutGraph } from '@/components/workout-graph';
import { StatsBar } from '@/components/ui/stats-bar';
import { BuilderHeader } from '@/components/ui/builder-header';
import { SegmentEditor } from '@/components/ui/segment-editor';
import { Plus, Save, Loader2 } from 'lucide-react';

function makeDefaultSegment(type: SegmentType, lastWorkPace: number | null, ftpWatts: number | null): WorkoutSegment {
  let pace: number | null = null;

  if (type === 'work') {
    pace = lastWorkPace;
  } else if (type === 'warmup' && ftpWatts) {
    // ~60% FTP for warmup
    pace = wattsToPaceTenths(ftpWatts * 0.6);
  } else if (type === 'cooldown' && ftpWatts) {
    // ~50% FTP for cooldown
    pace = wattsToPaceTenths(ftpWatts * 0.5);
  }

  const durationDefaults: Record<SegmentType, number> = {
    work: 300,
    rest: 60,
    warmup: 300,
    cooldown: 300,
  };

  return {
    type,
    duration_type: 'time',
    duration_value: durationDefaults[type],
    target_split: pace ? { pace } : null,
    target_stroke_rate: null,
    target_hr_zone: null,
    repeat: 1,
    messages: null,
  };
}

export default function BuilderPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const editId = searchParams.get('edit');

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [workoutType, setWorkoutType] = useState<WorkoutType>('intervals');
  const [tags, setTags] = useState<string[]>([]);
  const [isPublic, setIsPublic] = useState(true);
  const [segments, setSegments] = useState<WorkoutSegment[]>([]);
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [userId, setUserId] = useState<string | null>(null);

  const ftpWatts = profile?.current_ftp_watts ?? null;

  // Get the last work segment's pace for smart defaults
  const lastWorkPace = (() => {
    for (let i = segments.length - 1; i >= 0; i--) {
      if (segments[i].type === 'work' && segments[i].target_split) {
        return segments[i].target_split!.pace;
      }
    }
    return ftpWatts ? wattsToPaceTenths(ftpWatts) : null;
  })();

  // Load profile and optional edit workout
  useEffect(() => {
    const supabase = createSupabaseBrowser();

    async function init() {
      const { data: authData } = await supabase.auth.getUser();
      if (!authData.user) return;
      const currentUserId = authData.user.id;
      setUserId(currentUserId);

      const { data: profileData } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', currentUserId)
        .single();

      if (profileData) setProfile(profileData);

      if (editId) {
        const { data } = await supabase
          .from('workouts')
          .select('*')
          .eq('id', editId)
          .single();

        if (!data) return;

        // Verify ownership before populating form
        if (data.author_id !== currentUserId) {
          router.push('/workouts');
          return;
        }

        const w = data as Workout;
        setTitle(w.title);
        setDescription(w.description);
        setWorkoutType(w.workout_type);
        setTags(w.tags);
        setIsPublic(w.is_public);
        setSegments(normalizeWorkoutSegments(w.segments));
      }
    }

    init();
  }, [editId, router]);

  const addSegment = useCallback((type: SegmentType) => {
    const seg = makeDefaultSegment(type, lastWorkPace, ftpWatts);
    setSegments((prev) => [...prev, seg]);
    setSelectedIndex(segments.length);
  }, [lastWorkPace, ftpWatts, segments.length]);

  function updateSegment(index: number, segment: WorkoutSegment) {
    setSegments((prev) => prev.map((s, i) => (i === index ? segment : s)));
  }

  function removeSegment(index: number) {
    setSegments((prev) => prev.filter((_, i) => i !== index));
    setSelectedIndex(null);
  }

  async function handleSave() {
    setError(null);

    if (!title.trim()) {
      setError('Title is required');
      return;
    }
    if (segments.length < 1) {
      setError('Add at least one segment');
      return;
    }

    setSaving(true);
    const supabase = createSupabaseBrowser();

    try {
      const payload = {
        title: title.trim(),
        description: description.trim(),
        workout_type: workoutType,
        segments,
        tags,
        is_public: isPublic,
        author_id: userId,
      };

      if (editId) {
        if (!userId) throw new Error('Not authenticated');
        const { error: updateError } = await supabase
          .from('workouts')
          .update(payload)
          .eq('id', editId)
          .eq('author_id', userId);
        if (updateError) throw updateError;
        router.push(`/workouts/${editId}`);
      } else {
        const { data, error: insertError } = await supabase
          .from('workouts')
          .insert(payload)
          .select('id')
          .single();
        if (insertError) throw insertError;
        if (data) router.push(`/workouts/${data.id}`);
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to save workout');
    } finally {
      setSaving(false);
    }
  }

  const selectedSegment = selectedIndex !== null ? segments[selectedIndex] : null;

  return (
    <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="mb-6 text-3xl font-bold text-white">
        {editId ? 'Edit Workout' : 'Workout Builder'}
      </h1>

      {error && (
        <div className="mb-6 rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-400">
          {error}
        </div>
      )}

      {/* Header fields */}
      <div className="mb-8 rounded-xl border border-gray-800 bg-gray-900 p-6">
        <BuilderHeader
          title={title}
          description={description}
          workoutType={workoutType}
          tags={tags}
          isPublic={isPublic}
          onTitleChange={setTitle}
          onDescriptionChange={setDescription}
          onWorkoutTypeChange={setWorkoutType}
          onTagsChange={setTags}
          onPublicChange={setIsPublic}
        />
      </div>

      {/* Graph */}
      {segments.length > 0 && (
        <div className="mb-6">
          <WorkoutGraph
            segments={segments}
            selectedIndex={selectedIndex}
            onSelectSegment={setSelectedIndex}
          />
        </div>
      )}

      {/* Stats */}
      {segments.length > 0 && (
        <div className="mb-6">
          <StatsBar segments={segments} />
        </div>
      )}

      {/* Add segment buttons */}
      <div className="mb-6 flex flex-wrap gap-2">
        <button
          type="button"
          onClick={() => addSegment('work')}
          className="flex cursor-pointer items-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-500"
        >
          <Plus className="h-4 w-4" />
          Work
        </button>
        <button
          type="button"
          onClick={() => addSegment('rest')}
          className="flex cursor-pointer items-center gap-1.5 rounded-lg bg-gray-700 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-gray-600"
        >
          <Plus className="h-4 w-4" />
          Rest
        </button>
        <button
          type="button"
          onClick={() => addSegment('warmup')}
          className="flex cursor-pointer items-center gap-1.5 rounded-lg border border-emerald-500/50 bg-emerald-500/10 px-3 py-2 text-sm font-medium text-emerald-400 transition-colors hover:bg-emerald-500/20"
        >
          <Plus className="h-4 w-4" />
          Warm Up
        </button>
        <button
          type="button"
          onClick={() => addSegment('cooldown')}
          className="flex cursor-pointer items-center gap-1.5 rounded-lg border border-yellow-500/50 bg-yellow-500/10 px-3 py-2 text-sm font-medium text-yellow-400 transition-colors hover:bg-yellow-500/20"
        >
          <Plus className="h-4 w-4" />
          Cool Down
        </button>
      </div>

      {/* Segment editor */}
      {selectedSegment && selectedIndex !== null && (
        <div className="mb-6">
          <SegmentEditor
            segment={selectedSegment}
            onChange={(seg) => updateSegment(selectedIndex, seg)}
            onRemove={() => removeSegment(selectedIndex)}
          />
        </div>
      )}

      {/* Segment list (clickable to select) */}
      {segments.length > 0 && (
        <div className="mb-8 space-y-2">
          <h2 className="text-sm font-medium text-gray-400">Segments</h2>
          {segments.map((seg, i) => {
            const typeColors: Record<string, string> = {
              work: 'border-blue-500/30 bg-blue-500/5',
              rest: 'border-gray-500/30 bg-gray-500/5',
              warmup: 'border-emerald-500/30 bg-emerald-500/5',
              cooldown: 'border-yellow-500/30 bg-yellow-500/5',
            };
            const dotColors: Record<string, string> = {
              work: 'bg-blue-500',
              rest: 'bg-gray-500',
              warmup: 'bg-emerald-500',
              cooldown: 'bg-yellow-500',
            };

            return (
              <button
                key={i}
                type="button"
                onClick={() => setSelectedIndex(selectedIndex === i ? null : i)}
                className={`flex w-full cursor-pointer items-center gap-3 rounded-lg border p-3 text-left transition-colors ${
                  typeColors[seg.type]
                } ${selectedIndex === i ? 'ring-2 ring-blue-500' : ''}`}
              >
                <div className={`h-2.5 w-2.5 shrink-0 rounded-full ${dotColors[seg.type]}`} />
                <span className="text-sm font-medium text-white">
                  #{i + 1} {seg.type.charAt(0).toUpperCase() + seg.type.slice(1)}
                </span>
                <span className="text-sm text-gray-500">
                  {seg.duration_value}
                  {seg.duration_type === 'time' ? 's' : seg.duration_type === 'distance' ? 'm' : 'cal'}
                </span>
              </button>
            );
          })}
        </div>
      )}

      {/* Save button */}
      <div className="flex justify-end">
        <button
          type="button"
          onClick={handleSave}
          disabled={saving}
          className="flex cursor-pointer items-center gap-2 rounded-lg bg-blue-600 px-6 py-3 font-semibold text-white transition-colors hover:bg-blue-500 disabled:opacity-50"
        >
          {saving ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Save className="h-4 w-4" />
          )}
          {saving ? 'Saving...' : editId ? 'Update Workout' : 'Save Workout'}
        </button>
      </div>
    </div>
  );
}
