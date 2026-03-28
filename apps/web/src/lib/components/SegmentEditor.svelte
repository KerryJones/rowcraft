<script lang="ts">
	import type { WorkoutSegment, SegmentType, DurationType, SegmentMessage, HrZoneName } from '$lib/types';
	import { formatPace, parsePace, formatSegmentType } from '$lib/utils/format';
	import { paceTenthsToWatts, wattsToPaceTenths, formatWatts, HR_ZONES, getHrZoneBpm, getHrZoneNumber, getHrZoneFromNumber } from '$lib/utils/ftp';

	interface Props {
		segment: WorkoutSegment;
		ftpWatts: number | null;
		maxHeartRate: number | null;
		onUpdate: (segment: WorkoutSegment) => void;
	}

	let { segment, ftpWatts, maxHeartRate, onUpdate }: Props = $props();

	const segmentTypes: { value: SegmentType; label: string }[] = [
		{ value: 'work', label: 'Work' },
		{ value: 'rest', label: 'Rest' },
		{ value: 'warmup', label: 'Warm Up' },
		{ value: 'cooldown', label: 'Cool Down' }
	];

	const durationTypes: { value: DurationType; label: string }[] = [
		{ value: 'time', label: 'Time (sec)' },
		{ value: 'distance', label: 'Distance (m)' },
		{ value: 'calories', label: 'Calories' }
	];

	// Local state for pace input — intentionally captures initial segment values
	// svelte-ignore state_referenced_locally
	let paceInput = $state(segment.target_split ? formatPace(segment.target_split.pace) : '');
	// svelte-ignore state_referenced_locally
	let hasPaceTarget = $state(!!segment.target_split);
	// svelte-ignore state_referenced_locally
	let hasSpmTarget = $state(!!segment.target_stroke_rate);
	// svelte-ignore state_referenced_locally
	let spmValue = $state(segment.target_stroke_rate?.min ?? 24);

	// Watts display (derived from pace)
	const wattsDisplay = $derived(
		segment.target_split ? paceTenthsToWatts(segment.target_split.pace) : null
	);

	// FTP percentage display
	const ftpPercentDisplay = $derived(
		ftpWatts && segment.target_split
			? Math.round((paceTenthsToWatts(segment.target_split.pace) / ftpWatts) * 100)
			: null
	);

	// Current HR zone from segment
	const selectedZone = $derived(
		segment.target_hr_zone ? getHrZoneFromNumber(segment.target_hr_zone) : null
	);

	// Messages state
	// svelte-ignore state_referenced_locally
	let messages = $state<SegmentMessage[]>(segment.messages ?? []);

	function update(changes: Partial<WorkoutSegment>) {
		onUpdate({ ...segment, ...changes });
	}

	function handlePaceChange(e: Event) {
		const val = (e.target as HTMLInputElement).value;
		paceInput = val;
		const tenths = parsePace(val);
		if (tenths !== null) {
			update({ target_split: { pace: tenths } });
		}
	}

	function togglePaceTarget() {
		hasPaceTarget = !hasPaceTarget;
		if (hasPaceTarget) {
			const defaultPace = 1200; // 2:00
			paceInput = formatPace(defaultPace);
			update({ target_split: { pace: defaultPace } });
		} else {
			paceInput = '';
			update({ target_split: null });
		}
	}

	function toggleSpmTarget() {
		hasSpmTarget = !hasSpmTarget;
		if (hasSpmTarget) {
			update({ target_stroke_rate: { min: spmValue, max: spmValue } });
		} else {
			update({ target_stroke_rate: null });
		}
	}

	function handleSpmChange(e: Event) {
		const val = parseInt((e.target as HTMLInputElement).value) || 24;
		spmValue = val;
		update({ target_stroke_rate: { min: val, max: val } });
	}

	function selectHrZone(zoneName: HrZoneName) {
		const current = selectedZone;
		if (current === zoneName) {
			// Deselect
			update({ target_hr_zone: null });
		} else {
			update({ target_hr_zone: getHrZoneNumber(zoneName) });
		}
	}

	// Coaching cues
	function addMessage() {
		if (messages.length >= 5) return;
		messages = [...messages, { trigger_type: 'start', trigger_value: 0, text: '' }];
		update({ messages });
	}

	function updateMessage(index: number, changes: Partial<SegmentMessage>) {
		messages = messages.map((m, i) => (i === index ? { ...m, ...changes } : m));
		update({ messages });
	}

	function deleteMessage(index: number) {
		messages = messages.filter((_, i) => i !== index);
		update({ messages: messages.length > 0 ? messages : null });
	}
</script>

<div class="rounded-xl border border-gray-800 bg-gray-900 p-5 space-y-5">
	<div class="flex items-center justify-between">
		<h3 class="text-sm font-semibold text-white">Edit Segment</h3>
		<span class="text-xs text-gray-500">{formatSegmentType(segment.type)}</span>
	</div>

	<!-- Type + Duration row -->
	<div class="flex flex-wrap items-end gap-4">
		<div>
			<label for="seg-type" class="mb-1 block text-xs text-gray-500">Type</label>
			<select
				id="seg-type"
				value={segment.type}
				onchange={(e) => update({ type: (e.target as HTMLSelectElement).value as SegmentType })}
				class="rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
			>
				{#each segmentTypes as st}
					<option value={st.value}>{st.label}</option>
				{/each}
			</select>
		</div>

		<div>
			<span class="mb-1 block text-xs text-gray-500">Duration</span>
			<div class="flex items-center gap-2">
				<select
					value={segment.duration_type}
					onchange={(e) => update({ duration_type: (e.target as HTMLSelectElement).value as DurationType })}
					class="rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
				>
					{#each durationTypes as dt}
						<option value={dt.value}>{dt.label}</option>
					{/each}
				</select>
				<input
					type="number"
					value={segment.duration_value}
					onchange={(e) => update({ duration_value: parseInt((e.target as HTMLInputElement).value) || 0 })}
					min="1"
					class="w-24 rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
				/>
			</div>
		</div>

		<div>
			<label for="seg-repeat" class="mb-1 block text-xs text-gray-500">Repeat</label>
			<input
				id="seg-repeat"
				type="number"
				value={segment.repeat}
				onchange={(e) => update({ repeat: Math.max(1, parseInt((e.target as HTMLInputElement).value) || 1) })}
				min="1"
				class="w-20 rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm text-white"
			/>
		</div>
	</div>

	<!-- Target Pace -->
	<div>
		<!-- svelte-ignore a11y_label_has_associated_control -->
		<label class="flex items-center gap-2 text-sm text-gray-400 cursor-pointer">
			<input
				type="checkbox"
				checked={hasPaceTarget}
				onchange={togglePaceTarget}
				class="h-4 w-4 rounded border-gray-600 bg-gray-800 text-blue-600"
			/>
			Target Pace
		</label>
		{#if hasPaceTarget}
			<div class="mt-2 flex items-center gap-3">
				<input
					type="text"
					value={paceInput}
					onchange={handlePaceChange}
					placeholder="2:00"
					class="w-24 rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm font-mono text-white placeholder-gray-500 outline-none focus:border-blue-500"
				/>
				<span class="text-sm text-gray-500">/500m</span>
				{#if wattsDisplay}
					<span class="text-xs text-gray-600">{formatWatts(wattsDisplay!)}</span>
				{/if}
				{#if ftpPercentDisplay}
					<span class="text-xs text-gray-600">({ftpPercentDisplay}% FTP)</span>
				{/if}
			</div>
		{/if}
	</div>

	<!-- HR Zones -->
	{#if maxHeartRate}
		<div>
			<p class="mb-2 text-sm text-gray-400">HR Zone</p>
			<div class="flex flex-wrap gap-1.5">
				{#each HR_ZONES as zone}
					{@const bpm = getHrZoneBpm(maxHeartRate, zone.name)}
					{@const isActive = selectedZone === zone.name}
					<button
						type="button"
						onclick={() => selectHrZone(zone.name)}
						class="rounded-lg px-3 py-1.5 text-xs font-medium transition-colors
							{isActive
								? 'bg-blue-600 text-white'
								: 'border border-gray-700 bg-gray-800 text-gray-400 hover:border-gray-600 hover:text-white'}"
					>
						{zone.label}
						<span class="ml-1 opacity-60">{bpm.min}-{bpm.max}</span>
					</button>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Stroke Rate -->
	<div>
		<!-- svelte-ignore a11y_label_has_associated_control -->
		<label class="flex items-center gap-2 text-sm text-gray-400 cursor-pointer">
			<input
				type="checkbox"
				checked={hasSpmTarget}
				onchange={toggleSpmTarget}
				class="h-4 w-4 rounded border-gray-600 bg-gray-800 text-blue-600"
			/>
			Target Stroke Rate
		</label>
		{#if hasSpmTarget}
			<div class="mt-2 flex items-center gap-3">
				<input
					type="number"
					value={spmValue}
					onchange={handleSpmChange}
					min="10"
					max="50"
					class="w-20 rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm font-mono text-white outline-none focus:border-blue-500"
				/>
				<span class="text-sm text-gray-500">spm</span>
			</div>
		{/if}
	</div>

	<!-- Coaching Cues -->
	<div>
		<div class="mb-2 flex items-center justify-between">
			<p class="text-sm text-gray-400">Coaching Cues</p>
			{#if messages.length < 5}
				<button
					type="button"
					onclick={addMessage}
					class="rounded px-2 py-1 text-xs text-blue-400 hover:bg-blue-500/10"
				>
					+ Add Cue
				</button>
			{/if}
		</div>
		{#if messages.length > 0}
			<div class="space-y-2">
				{#each messages as msg, i}
					<div class="flex items-center gap-2">
						<select
							value={msg.trigger_type}
							onchange={(e) => updateMessage(i, { trigger_type: (e.target as HTMLSelectElement).value as SegmentMessage['trigger_type'] })}
							class="rounded border border-gray-700 bg-gray-800 px-2 py-1.5 text-xs text-white"
						>
							<option value="start">Start</option>
							<option value="end">End</option>
							<option value="time">At Time</option>
							<option value="distance">At Distance</option>
						</select>
						{#if msg.trigger_type === 'time'}
							<input
								type="number"
								value={msg.trigger_value}
								onchange={(e) => updateMessage(i, { trigger_value: parseInt((e.target as HTMLInputElement).value) || 0 })}
								placeholder="sec"
								class="w-16 rounded border border-gray-700 bg-gray-800 px-2 py-1.5 text-xs text-white"
							/>
						{:else if msg.trigger_type === 'distance'}
							<input
								type="number"
								value={msg.trigger_value}
								onchange={(e) => updateMessage(i, { trigger_value: parseInt((e.target as HTMLInputElement).value) || 0 })}
								placeholder="m"
								class="w-16 rounded border border-gray-700 bg-gray-800 px-2 py-1.5 text-xs text-white"
							/>
						{/if}
						<input
							type="text"
							value={msg.text}
							onchange={(e) => updateMessage(i, { text: (e.target as HTMLInputElement).value })}
							placeholder="e.g., Pick up the pace!"
							class="flex-1 rounded border border-gray-700 bg-gray-800 px-2 py-1.5 text-xs text-white placeholder-gray-600"
						/>
						<button
							type="button"
							onclick={() => deleteMessage(i)}
							class="rounded p-1 text-gray-500 hover:text-red-400"
							aria-label="Delete cue"
						>
							<svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
							</svg>
						</button>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>
