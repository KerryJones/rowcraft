<script lang="ts">
	import type { WorkoutSegment } from '$lib/types';
	import { formatPace, formatSegmentDuration, formatSegmentType } from '$lib/utils/format';
	import { paceTenthsToWatts, formatWatts, getHrZoneFromNumber, getHrZoneLabel } from '$lib/utils/ftp';

	interface Props {
		segment: WorkoutSegment;
		index: number;
	}

	let { segment, index }: Props = $props();

	const borderColors: Record<string, string> = {
		work: 'border-l-blue-500',
		rest: 'border-l-gray-500',
		warmup: 'border-l-emerald-500',
		cooldown: 'border-l-yellow-500'
	};

	const wattsDisplay = $derived(
		segment.target_split
			? formatWatts(paceTenthsToWatts(segment.target_split.pace))
			: null
	);

	const hrZoneDisplay = $derived(
		segment.target_hr_zone
			? (() => { const name = getHrZoneFromNumber(segment.target_hr_zone!); return name ? getHrZoneLabel(name) : null; })()
			: null
	);
</script>

<div class="rounded-lg border border-gray-800 bg-gray-900 border-l-4 {borderColors[segment.type] ?? 'border-l-gray-500'}">
	<div class="px-4 py-3">
		<div class="flex items-center justify-between">
			<div class="flex items-center gap-3">
				<span class="text-sm font-medium text-gray-600">{index + 1}</span>
				<span class="text-sm font-semibold text-white">{formatSegmentType(segment.type)}</span>
				<span class="font-mono text-sm text-gray-400">{formatSegmentDuration(segment)}</span>
				{#if segment.repeat > 1}
					<span class="rounded bg-gray-800 px-2 py-0.5 text-xs text-gray-400">
						x{segment.repeat}
					</span>
				{/if}
			</div>
			<div class="flex items-center gap-4 text-sm text-gray-400">
				{#if segment.target_split}
					<span class="font-mono">{formatPace(segment.target_split.pace)}/500m</span>
					{#if wattsDisplay}
						<span class="text-xs text-gray-600">{wattsDisplay}</span>
					{/if}
				{/if}
				{#if segment.target_stroke_rate}
					<span>{segment.target_stroke_rate.min} spm</span>
				{/if}
				{#if hrZoneDisplay}
					<span class="text-xs rounded bg-blue-500/10 px-2 py-0.5 text-blue-400">{hrZoneDisplay}</span>
				{/if}
			</div>
		</div>

		<!-- Coaching cues -->
		{#if segment.messages && segment.messages.length > 0}
			<div class="mt-2 flex flex-wrap gap-1.5">
				{#each segment.messages as msg}
					<span class="inline-flex items-center gap-1 rounded-full bg-gray-800 px-2.5 py-0.5 text-xs text-gray-400">
						{#if msg.trigger_type === 'start'}
							<span class="text-emerald-500">Start:</span>
						{:else if msg.trigger_type === 'end'}
							<span class="text-red-400">End:</span>
						{:else if msg.trigger_type === 'time'}
							<span class="text-blue-400">@{msg.trigger_value}s:</span>
						{:else if msg.trigger_type === 'distance'}
							<span class="text-blue-400">@{msg.trigger_value}m:</span>
						{/if}
						{msg.text}
					</span>
				{/each}
			</div>
		{/if}
	</div>
</div>
