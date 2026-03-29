'use client';

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createSupabaseBrowser } from '@/lib/supabase/client';
import type { TrainingPlan, Difficulty, PlanWeek, PlanSession } from '@/lib/types';
import { WorkoutPicker } from '@/components/ui/workout-picker';
import { Plus, Trash2, Save, Loader2, ChevronDown, ChevronRight } from 'lucide-react';

function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function makeEmptySession(): PlanSession {
  return { day_label: '', workout_id: '', notes: null };
}

function makeEmptyWeek(weekNumber: number): PlanWeek {
  return {
    week_number: weekNumber,
    title: '',
    sessions: [makeEmptySession()],
  };
}

const DIFFICULTIES: { value: Difficulty; label: string }[] = [
  { value: 'beginner', label: 'Beginner' },
  { value: 'intermediate', label: 'Intermediate' },
  { value: 'advanced', label: 'Advanced' },
];

export default function PlanBuilderPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const editId = searchParams.get('edit');

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [difficulty, setDifficulty] = useState<Difficulty>('beginner');
  const [tags, setTags] = useState<string[]>([]);
  const [weeks, setWeeks] = useState<PlanWeek[]>([makeEmptyWeek(1)]);
  const [originalSlug, setOriginalSlug] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [openWeeks, setOpenWeeks] = useState<Set<number>>(new Set([0]));
  const [workoutOptions, setWorkoutOptions] = useState<{ id: string; title: string }[]>([]);
  const [userId, setUserId] = useState<string | null>(null);

  const slug = slugify(title);

  useEffect(() => {
    const supabase = createSupabaseBrowser();

    async function init() {
      // Resolve auth first
      const { data: authData } = await supabase.auth.getUser();
      const currentUserId = authData.user?.id ?? null;
      if (currentUserId) setUserId(currentUserId);

      // Fetch workouts for picker (parallel with edit load)
      supabase
        .from('workouts')
        .select('id, title')
        .order('title')
        .then(({ data }) => {
          if (data) setWorkoutOptions(data);
        });

      // Edit mode — only load plan after auth is resolved
      if (editId) {
        const { data } = await supabase
          .from('training_plans')
          .select('*')
          .eq('id', editId)
          .single();

        if (!data) return;

        // Verify ownership before populating form
        if (data.author_id && currentUserId !== data.author_id) {
          router.push('/plans');
          return;
        }

        const plan = data as TrainingPlan;
        setTitle(plan.title);
        setDescription(plan.description);
        setDifficulty(plan.difficulty);
        setTags(plan.tags);
        setWeeks(plan.weeks);
        setOriginalSlug(plan.slug);
      }
    }

    init();
  }, [editId, router]);

  function toggleWeek(index: number) {
    setOpenWeeks((prev) => {
      const next = new Set(prev);
      if (next.has(index)) next.delete(index);
      else next.add(index);
      return next;
    });
  }

  function addWeek() {
    const newWeek = makeEmptyWeek(weeks.length + 1);
    setWeeks((prev) => [...prev, newWeek]);
    setOpenWeeks((prev) => new Set(prev).add(weeks.length));
  }

  function removeWeek(index: number) {
    setWeeks((prev) => {
      const next = prev.filter((_, i) => i !== index);
      // Re-number weeks
      return next.map((w, i) => ({ ...w, week_number: i + 1 }));
    });
  }

  function updateWeekTitle(weekIndex: number, value: string) {
    setWeeks((prev) =>
      prev.map((w, i) => (i === weekIndex ? { ...w, title: value } : w))
    );
  }

  function addSession(weekIndex: number) {
    setWeeks((prev) =>
      prev.map((w, i) =>
        i === weekIndex
          ? { ...w, sessions: [...w.sessions, makeEmptySession()] }
          : w
      )
    );
  }

  function removeSession(weekIndex: number, sessionIndex: number) {
    setWeeks((prev) =>
      prev.map((w, i) =>
        i === weekIndex
          ? { ...w, sessions: w.sessions.filter((_, j) => j !== sessionIndex) }
          : w
      )
    );
  }

  function updateSession(weekIndex: number, sessionIndex: number, updates: Partial<PlanSession>) {
    setWeeks((prev) =>
      prev.map((w, i) =>
        i === weekIndex
          ? {
              ...w,
              sessions: w.sessions.map((s, j) =>
                j === sessionIndex ? { ...s, ...updates } : s
              ),
            }
          : w
      )
    );
  }

  // Compute sessions_per_week as the max sessions in any week
  const sessionsPerWeek = Math.max(1, ...weeks.map((w) => w.sessions.length));

  async function handleSave() {
    setError(null);

    if (!title.trim()) {
      setError('Title is required');
      return;
    }

    setSaving(true);
    const supabase = createSupabaseBrowser();

    try {
      const payload = {
        title: title.trim(),
        slug,
        description: description.trim(),
        difficulty,
        duration_weeks: weeks.length,
        sessions_per_week: sessionsPerWeek,
        tags,
        weeks,
        is_active: true,
        author_id: userId,
      };

      if (editId) {
        if (!userId) throw new Error('Not authenticated');
        const { error: updateError } = await supabase
          .from('training_plans')
          .update(payload)
          .eq('id', editId)
          .eq('author_id', userId);
        if (updateError) throw updateError;
      } else {
        const { error: insertError } = await supabase
          .from('training_plans')
          .insert(payload);
        if (insertError) throw insertError;
      }

      router.push(`/plans/${editId ? originalSlug ?? slug : slug}`);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to save plan');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="mx-auto max-w-5xl px-4 py-8 sm:px-6 lg:px-8">
      <h1 className="mb-6 text-3xl font-bold text-white">
        {editId ? 'Edit Plan' : 'Plan Builder'}
      </h1>

      {error && (
        <div className="mb-6 rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-400">
          {error}
        </div>
      )}

      {/* Plan metadata */}
      <div className="mb-8 space-y-4 rounded-xl border border-gray-800 bg-gray-900 p-6">
        <div>
          <label className="mb-1 block text-sm font-medium text-gray-400">Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Plan title"
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          />
          {slug && (
            <p className="mt-1 text-xs text-gray-500">
              Slug: <span className="text-gray-400">{slug}</span>
            </p>
          )}
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium text-gray-400">Description</label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Describe the plan..."
            rows={3}
            className="w-full rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
          />
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-400">Difficulty</label>
            <select
              value={difficulty}
              onChange={(e) => setDifficulty(e.target.value as Difficulty)}
              className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2.5 text-sm text-white"
            >
              {DIFFICULTIES.map((d) => (
                <option key={d.value} value={d.value}>{d.label}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-400">Tags (comma separated)</label>
            <input
              type="text"
              value={tags.join(', ')}
              onChange={(e) =>
                setTags(
                  e.target.value.split(',').map((t) => t.trim()).filter(Boolean)
                )
              }
              placeholder="endurance, beginner"
              className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2.5 text-sm text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
            />
          </div>
        </div>
      </div>

      {/* Preview panel */}
      <div className="mb-8 rounded-lg border border-gray-800 bg-gray-900/50 p-4">
        <h3 className="mb-2 text-sm font-medium text-gray-400">Preview</h3>
        <p className="text-sm text-gray-500">
          {weeks.length} week{weeks.length !== 1 ? 's' : ''} &middot;{' '}
          {sessionsPerWeek} sessions/week &middot;{' '}
          {difficulty.charAt(0).toUpperCase() + difficulty.slice(1)}
        </p>
      </div>

      {/* Weeks */}
      <div className="mb-6 space-y-3">
        {weeks.map((week, wi) => {
          const isOpen = openWeeks.has(wi);

          return (
            <div
              key={wi}
              className="rounded-xl border border-gray-800 bg-gray-900 overflow-hidden"
            >
              <div
                role="button"
                tabIndex={0}
                onClick={() => toggleWeek(wi)}
                onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') toggleWeek(wi); }}
                className="flex w-full cursor-pointer items-center justify-between p-4 text-left"
              >
                <span className="text-sm font-semibold text-white">
                  Week {week.week_number}
                </span>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      removeWeek(wi);
                    }}
                    className="cursor-pointer text-gray-500 hover:text-red-400"
                    title="Remove week"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                  {isOpen ? (
                    <ChevronDown className="h-4 w-4 text-gray-400" />
                  ) : (
                    <ChevronRight className="h-4 w-4 text-gray-400" />
                  )}
                </div>
              </div>

              {isOpen && (
                <div className="border-t border-gray-800 p-4 space-y-3">
                  <input
                    type="text"
                    value={week.title}
                    onChange={(e) => updateWeekTitle(wi, e.target.value)}
                    placeholder="Week title (optional)"
                    className="w-full rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none"
                  />

                  {week.sessions.map((session, si) => (
                    <div key={si} className="flex items-start gap-2 rounded-lg bg-gray-800/50 p-3">
                      <div className="flex-1 space-y-2">
                        <input
                          type="text"
                          value={session.day_label}
                          onChange={(e) =>
                            updateSession(wi, si, { day_label: e.target.value })
                          }
                          placeholder="Day label (e.g., Mon)"
                          className="w-full rounded border border-gray-600 bg-gray-900 px-2 py-1.5 text-sm text-white placeholder-gray-500 focus:outline-none"
                        />
                        <WorkoutPicker
                          workouts={workoutOptions}
                          selectedId={session.workout_id || null}
                          onChange={(id) => updateSession(wi, si, { workout_id: id })}
                          placeholder="Select workout..."
                        />
                        <input
                          type="text"
                          value={session.notes ?? ''}
                          onChange={(e) =>
                            updateSession(wi, si, {
                              notes: e.target.value || null,
                            })
                          }
                          placeholder="Notes (optional)"
                          className="w-full rounded border border-gray-600 bg-gray-900 px-2 py-1.5 text-sm text-white placeholder-gray-500 focus:outline-none"
                        />
                      </div>
                      <button
                        type="button"
                        onClick={() => removeSession(wi, si)}
                        className="mt-1 cursor-pointer text-gray-500 hover:text-red-400"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  ))}

                  <button
                    type="button"
                    onClick={() => addSession(wi)}
                    className="flex cursor-pointer items-center gap-1.5 text-sm text-blue-400 hover:text-blue-300"
                  >
                    <Plus className="h-4 w-4" />
                    Add Session
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>

      <button
        type="button"
        onClick={addWeek}
        className="mb-8 flex cursor-pointer items-center gap-1.5 text-sm font-medium text-blue-400 hover:text-blue-300"
      >
        <Plus className="h-4 w-4" />
        Add Week
      </button>

      {/* Save */}
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
          {saving ? 'Saving...' : editId ? 'Update Plan' : 'Save Plan'}
        </button>
      </div>
    </div>
  );
}
