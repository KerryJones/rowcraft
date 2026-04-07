'use client';

import { useState, useEffect, useRef } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createSupabaseBrowser } from '@/lib/supabase/client';
import type { Workout, WorkoutSegment, WorkoutType, Profile } from '@/lib/types';
import { normalizeWorkoutSegments } from '@/lib/types';
import { intensityToHrZone } from '@/lib/utils/ftp';
import { WorkoutGraph } from '@/components/workout-graph';
import { StatsBar } from '@/components/ui/stats-bar';
import { BuilderHeader } from '@/components/ui/builder-header';
import { SegmentEditor } from '@/components/ui/segment-editor';
import { BuilderSegmentItem } from '@/components/ui/builder-segment-item';
import { validateWorkout } from '@/lib/utils/builder-validation';
import { Plus, Save, Loader2, Dumbbell } from 'lucide-react';

function makeDefaultSegment(lastIntensity: number | null): WorkoutSegment {
  const intensity = lastIntensity ?? 90;
  return {
    duration_type: 'time',
    duration_value: 300,
    target_intensity: intensity,
    target_stroke_rate: null,
    target_hr_zone: intensityToHrZone(intensity),
    messages: null,
  };
}

export default function BuilderPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const editId = searchParams.get('edit');
  const editorRef = useRef<HTMLDivElement>(null);
  const scrollToEditor = () =>
    setTimeout(() => editorRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' }), 50);

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
  const [hasEdited, setHasEdited] = useState(false);

  const ftpWatts = profile?.current_ftp_watts ?? null;
  const lastWorkIntensity = (() => {
    for (let i = segments.length - 1; i >= 0; i--) {
      if (segments[i].target_intensity != null) {
        return segments[i].target_intensity;
      }
    }
    return null;
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

  useEffect(() => {
    function handleBeforeUnload(e: BeforeUnloadEvent) {
      if (hasEdited) {
        e.preventDefault();
      }
    }
    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [hasEdited]);

  function addSegment() {
    const seg = makeDefaultSegment(lastWorkIntensity);
    const newIndex = segments.length;
    setSegments((prev) => [...prev, seg]);
    setSelectedIndex(newIndex);
    setHasEdited(true);
    scrollToEditor();
  }

  function handleSelectSegment(index: number) {
    setSelectedIndex(selectedIndex === index ? null : index);
    if (selectedIndex !== index) {
      scrollToEditor();
    }
  }

  function updateSegment(index: number, segment: WorkoutSegment) {
    setSegments((prev) => prev.map((s, i) => (i === index ? segment : s)));
    setHasEdited(true);
  }

  function removeSegment(index: number) {
    setSegments((prev) => prev.filter((_, i) => i !== index));
    setSelectedIndex(null);
    setHasEdited(true);
  }

  function moveSegment(fromIndex: number, direction: 'up' | 'down') {
    const toIndex = direction === 'up' ? fromIndex - 1 : fromIndex + 1;
    if (toIndex < 0 || toIndex >= segments.length) return;
    setSegments((prev) => {
      const next = [...prev];
      [next[fromIndex], next[toIndex]] = [next[toIndex], next[fromIndex]];
      return next;
    });
    if (selectedIndex === fromIndex) setSelectedIndex(toIndex);
    else if (selectedIndex === toIndex) setSelectedIndex(fromIndex);
    setHasEdited(true);
  }

  function duplicateSegment(index: number) {
    setSegments((prev) => {
      const next = [...prev];
      next.splice(index + 1, 0, { ...prev[index] });
      return next;
    });
    setSelectedIndex(index + 1);
    setHasEdited(true);
    scrollToEditor();
  }

  async function handleSave() {
    setError(null);

    const validation = validateWorkout(title, segments);
    if (!validation.valid) {
      setError(validation.error);
      return;
    }

    if (!userId) {
      setError('Not authenticated');
      return;
    }

    setSaving(true);
    const supabase = createSupabaseBrowser();

    try {
      // Ensure hr_zone is derived from intensity before saving
    const normalizedSegments = segments.map((s) => ({
      ...s,
      target_hr_zone: intensityToHrZone(s.target_intensity),
    }));

    const payload = {
        title: title.trim(),
        description: description.trim(),
        workout_type: workoutType,
        segments: normalizedSegments,
        tags,
        is_public: isPublic,
        author_id: userId,
      };

      if (editId) {
        const { error: updateError } = await supabase
          .from('workouts')
          .update(payload)
          .eq('id', editId)
          .eq('author_id', userId);
        if (updateError) throw updateError;
        setHasEdited(false);
        router.push(`/workouts/${editId}`);
      } else {
        const { data, error: insertError } = await supabase
          .from('workouts')
          .insert(payload)
          .select('id')
          .single();
        if (insertError) throw insertError;
        setHasEdited(false);
        if (data) router.push(`/workouts/${data.id}`);
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to save workout');
    } finally {
      setSaving(false);
    }
  }

  const selectedSegment = selectedIndex !== null ? segments[selectedIndex] : null;

  const addSegmentButton = (
    <button
      type="button"
      onClick={() => addSegment()}
      className="flex cursor-pointer items-center gap-1.5 rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-500"
    >
      <Plus className="h-4 w-4" />
      Add Segment
    </button>
  );

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
          onTitleChange={(v) => { setTitle(v); setHasEdited(true); }}
          onDescriptionChange={(v) => { setDescription(v); setHasEdited(true); }}
          onWorkoutTypeChange={(v) => { setWorkoutType(v); setHasEdited(true); }}
          onTagsChange={(v) => { setTags(v); setHasEdited(true); }}
          onPublicChange={(v) => { setIsPublic(v); setHasEdited(true); }}
        />
      </div>

      {segments.length === 0 ? (
        /* Empty state */
        <div className="mb-8 flex flex-col items-center justify-center rounded-xl border border-dashed border-gray-700 bg-gray-900/50 px-8 py-16 text-center">
          <div className="mb-4 rounded-full bg-gray-800 p-4">
            <Dumbbell className="h-8 w-8 text-gray-500" />
          </div>
          <h3 className="mb-1 text-lg font-medium text-white">No segments yet</h3>
          <p className="mb-6 max-w-xs text-sm text-gray-500">
            Add your first segment to start building your workout.
          </p>
          {addSegmentButton}
        </div>
      ) : (
        <>
          {/* Graph */}
          <div className="mb-4">
            <WorkoutGraph
              segments={segments}
              selectedIndex={selectedIndex}
              onSelectSegment={handleSelectSegment}
            />
          </div>

          {/* Stats */}
          <div className="mb-6">
            <StatsBar segments={segments} />
          </div>

          {/* Segment list */}
          <div className="mb-4 space-y-1.5">
            <h2 className="mb-2 text-sm font-medium text-gray-400">Segments</h2>
            {segments.map((seg, i) => (
              <BuilderSegmentItem
                key={i}
                segment={seg}
                index={i}
                isSelected={selectedIndex === i}
                isFirst={i === 0}
                isLast={i === segments.length - 1}
                onSelect={() => handleSelectSegment(i)}
                onMoveUp={() => moveSegment(i, 'up')}
                onMoveDown={() => moveSegment(i, 'down')}
                onDuplicate={() => duplicateSegment(i)}
              />
            ))}
          </div>

          {/* Add segment button */}
          <div className="mb-6">{addSegmentButton}</div>
        </>
      )}

      {/* Segment editor */}
      <div ref={editorRef}>
        {selectedSegment !== null && selectedIndex !== null && (
          <div className="mb-6">
            <SegmentEditor
              segment={selectedSegment}
              onChange={(seg) => updateSegment(selectedIndex, seg)}
              onRemove={() => removeSegment(selectedIndex)}
              onDuplicate={() => duplicateSegment(selectedIndex)}
              ftpWatts={ftpWatts}
            />
          </div>
        )}
      </div>

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
