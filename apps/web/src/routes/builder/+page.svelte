<script lang="ts">
	import { goto } from '$app/navigation';
	import BuilderHeader from '$lib/components/BuilderHeader.svelte';
	import WorkoutGraphHero from '$lib/components/WorkoutGraphHero.svelte';
	import SegmentTimeline from '$lib/components/SegmentTimeline.svelte';
	import SegmentEditor from '$lib/components/SegmentEditor.svelte';
	import type { WorkoutSegment, WorkoutType, SegmentType } from '$lib/types';
	import { formatDuration, formatDistance } from '$lib/utils/format';
	import { wattsToPaceTenths } from '$lib/utils/ftp';
	import { computeTotalTime, computeTotalDistance, computeSegmentCount } from '$lib/utils/workout';

	let { data } = $props();

	let title = $state('');
	let description = $state('');
	let workoutType = $state<WorkoutType>('intervals');
	let isPublic = $state(false);
	let tags = $state<string[]>([]);
	let segments = $state<WorkoutSegment[]>([]);
	let selectedIndex = $state<number | null>(null);
	let saving = $state(false);
	let errors = $state<Record<string, string>>({});

	// User's FTP and Max HR — loaded from profile
	let ftpWatts = $state<number | null>(null);
	let maxHeartRate = $state<number | null>(null);

	// Load profile data on mount (once)
	let profileLoaded = false;
	$effect(() => {
		if (data.supabase && data.session?.user && !profileLoaded) {
			profileLoaded = true;
			data.supabase
				.from('profiles')
				.select('current_ftp_watts, max_heart_rate')
				.eq('id', data.session.user.id)
				.single()
				.then(({ data: profile }: { data: any }) => {
					if (profile) {
						ftpWatts = profile.current_ftp_watts ?? null;
						maxHeartRate = profile.max_heart_rate ?? null;
					}
				});
		}
	});

	// Computed summaries
	const totalTime = $derived(computeTotalTime(segments));
	const totalDistance = $derived(computeTotalDistance(segments));
	const segmentCount = $derived(computeSegmentCount(segments));
	const selectedSegment = $derived(
		selectedIndex !== null && selectedIndex < segments.length
			? segments[selectedIndex]
			: null
	);

	function defaultPaceForType(type: SegmentType): number | null {
		// Find the last work segment's pace to copy
		if (type === 'work') {
			for (let i = segments.length - 1; i >= 0; i--) {
				if (segments[i].type === 'work' && segments[i].target_split) {
					return segments[i].target_split!.pace;
				}
			}
			// No previous work — use FTP or 2:00
			if (ftpWatts) return wattsToPaceTenths(ftpWatts);
			return 1200; // 2:00
		}
		if (type === 'warmup') {
			if (ftpWatts) return wattsToPaceTenths(ftpWatts * 0.6); // ~60% FTP
			return 1350; // 2:15
		}
		if (type === 'cooldown') {
			if (ftpWatts) return wattsToPaceTenths(ftpWatts * 0.5); // ~50% FTP
			return 1400; // 2:20
		}
		return null; // rest
	}

	function addSegment(type: SegmentType) {
		const defaultPace = defaultPaceForType(type);
		const newSegment: WorkoutSegment = {
			type,
			duration_type: 'time',
			duration_value: type === 'rest' ? 60 : type === 'work' ? 300 : 180,
			target_split: defaultPace ? { pace: defaultPace } : null,
			target_stroke_rate: null,
			target_hr_zone: null,
			repeat: 1,
			messages: null
		};
		segments = [...segments, newSegment];
		selectedIndex = segments.length - 1;
	}

	function updateSegment(index: number, updated: WorkoutSegment) {
		segments = segments.map((s, i) => (i === index ? updated : s));
	}

	function deleteSegment(index: number) {
		segments = segments.filter((_, i) => i !== index);
		if (selectedIndex === index) {
			selectedIndex = segments.length > 0 ? Math.min(index, segments.length - 1) : null;
		} else if (selectedIndex !== null && selectedIndex > index) {
			selectedIndex--;
		}
	}

	function moveSegment(index: number, direction: 'up' | 'down') {
		const newIndex = direction === 'up' ? index - 1 : index + 1;
		if (newIndex < 0 || newIndex >= segments.length) return;
		const newSegments = [...segments];
		[newSegments[index], newSegments[newIndex]] = [newSegments[newIndex], newSegments[index]];
		segments = newSegments;
		selectedIndex = newIndex;
	}

	function duplicateSegment(index: number) {
		const copy = { ...segments[index] };
		segments = [...segments.slice(0, index + 1), copy, ...segments.slice(index + 1)];
		selectedIndex = index + 1;
	}

	function validate(): boolean {
		const newErrors: Record<string, string> = {};
		if (!title.trim()) newErrors.title = 'Title is required';
		if (segments.length === 0) newErrors.segments = 'Add at least one segment';
		segments.forEach((seg, i) => {
			if (seg.duration_value <= 0) {
				newErrors[`segment_${i}`] = 'Duration must be greater than 0';
			}
		});
		errors = newErrors;
		return Object.keys(newErrors).length === 0;
	}

	async function saveWorkout() {
		if (!validate()) return;
		saving = true;

		try {
			const { supabase, session } = data;
			if (!supabase || !session?.user) {
				goto('/auth/login');
				return;
			}

			const { data: workout, error } = await supabase.from('workouts').insert({
				author_id: session.user.id,
				title: title.trim(),
				description: description.trim(),
				workout_type: workoutType,
				segments,
				tags,
				is_public: isPublic
			}).select().single();

			if (error) throw error;
			goto(`/workouts/${workout.id}`);
		} catch (err) {
			errors = { save: 'Failed to save workout. Please try again.' };
		} finally {
			saving = false;
		}
	}
</script>

<svelte:head>
	<title>Workout Builder - RowCraft</title>
</svelte:head>

<div class="mx-auto max-w-5xl px-4 py-6 sm:px-6 lg:px-8 space-y-4">
	<!-- Header (collapsible metadata) -->
	<BuilderHeader
		{title}
		{description}
		{workoutType}
		{tags}
		{isPublic}
		onTitleChange={(v) => (title = v)}
		onDescriptionChange={(v) => (description = v)}
		onWorkoutTypeChange={(v) => (workoutType = v)}
		onTagsChange={(v) => (tags = v)}
		onPublicChange={(v) => (isPublic = v)}
	/>

	{#if errors.title}
		<p class="text-sm text-red-400">{errors.title}</p>
	{/if}

	<!-- Hero graph -->
	<WorkoutGraphHero
		{segments}
		{selectedIndex}
		onSelectSegment={(i) => (selectedIndex = i)}
	/>

	<!-- Segment timeline -->
	<SegmentTimeline
		{segments}
		{selectedIndex}
		onSelect={(i) => (selectedIndex = i)}
		onMove={moveSegment}
		onDelete={deleteSegment}
		onDuplicate={duplicateSegment}
		onAdd={addSegment}
	/>

	{#if errors.segments}
		<p class="text-sm text-red-400">{errors.segments}</p>
	{/if}

	<!-- Segment editor (inline, shown when a segment is selected) -->
	{#if selectedSegment && selectedIndex !== null}
		{#key selectedIndex}
			<SegmentEditor
				segment={selectedSegment}
				{ftpWatts}
				{maxHeartRate}
				onUpdate={(updated) => updateSegment(selectedIndex!, updated)}
			/>
		{/key}
	{/if}

	<!-- Summary + Save -->
	<div class="flex items-center justify-between rounded-xl border border-gray-800 bg-gray-900 px-5 py-4">
		<div class="flex items-center gap-6 text-sm">
			{#if totalTime}
				<div>
					<span class="text-xs text-gray-500">TIME</span>
					<p class="font-mono text-white">{formatDuration(totalTime)}</p>
				</div>
			{/if}
			{#if totalDistance}
				<div>
					<span class="text-xs text-gray-500">DISTANCE</span>
					<p class="font-mono text-white">{formatDistance(totalDistance)}</p>
				</div>
			{/if}
			<div>
				<span class="text-xs text-gray-500">SEGMENTS</span>
				<p class="font-mono text-white">{segmentCount}</p>
			</div>
		</div>
		<div class="flex items-center gap-3">
			{#if errors.save}
				<p class="text-sm text-red-400">{errors.save}</p>
			{/if}
			<button
				onclick={saveWorkout}
				disabled={saving}
				class="rounded-lg bg-blue-600 px-6 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-blue-500 disabled:opacity-50"
			>
				{saving ? 'Saving...' : 'Save Workout'}
			</button>
		</div>
	</div>
</div>
