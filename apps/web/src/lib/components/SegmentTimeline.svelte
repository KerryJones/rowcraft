<script lang="ts">
	import type { WorkoutSegment, SegmentType } from '$lib/types';
	import { formatSegmentDuration, formatSegmentType } from '$lib/utils/format';

	interface Props {
		segments: WorkoutSegment[];
		selectedIndex: number | null;
		onSelect: (index: number) => void;
		onMove: (index: number, direction: 'up' | 'down') => void;
		onDelete: (index: number) => void;
		onDuplicate: (index: number) => void;
		onAdd: (type: SegmentType) => void;
	}

	let { segments, selectedIndex, onSelect, onMove, onDelete, onDuplicate, onAdd }: Props = $props();

	const borderColors: Record<string, string> = {
		work: 'border-blue-500',
		rest: 'border-gray-500',
		warmup: 'border-emerald-500',
		cooldown: 'border-yellow-500'
	};

	const bgColors: Record<string, string> = {
		work: 'bg-blue-500/10',
		rest: 'bg-gray-500/10',
		warmup: 'bg-emerald-500/10',
		cooldown: 'bg-yellow-500/10'
	};

	const addButtons: { type: SegmentType; label: string; colorClass: string }[] = [
		{ type: 'work', label: '+ Work', colorClass: 'border-blue-500/30 bg-blue-500/10 text-blue-400 hover:bg-blue-500/20' },
		{ type: 'rest', label: '+ Rest', colorClass: 'border-gray-600/30 bg-gray-600/10 text-gray-400 hover:bg-gray-600/20' },
		{ type: 'warmup', label: '+ Warm Up', colorClass: 'border-emerald-500/30 bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20' },
		{ type: 'cooldown', label: '+ Cool Down', colorClass: 'border-yellow-500/30 bg-yellow-500/10 text-yellow-400 hover:bg-yellow-500/20' },
	];
</script>

<div class="flex gap-2 overflow-x-auto pb-2">
	{#each segments as segment, i}
		<button
			type="button"
			class="relative shrink-0 rounded-lg border-l-4 px-3 py-2 text-left transition-all
				{borderColors[segment.type] ?? 'border-gray-500'}
				{selectedIndex === i
					? 'ring-2 ring-blue-400 bg-gray-800'
					: 'bg-gray-900 border border-gray-800 hover:bg-gray-800/50'}"
			style="min-width: 100px; max-width: 160px;"
			onclick={() => onSelect(i)}
		>
			<p class="text-xs font-semibold text-white truncate">{formatSegmentType(segment.type)}</p>
			<p class="text-xs text-gray-400 font-mono">{formatSegmentDuration(segment)}</p>
			{#if segment.repeat > 1}
				<span class="absolute top-1 right-1 rounded bg-gray-700 px-1.5 py-0.5 text-[10px] font-medium text-gray-300">
					x{segment.repeat}
				</span>
			{/if}
		</button>
	{/each}

	<!-- Add segment buttons -->
	<div class="flex shrink-0 gap-1 items-center">
		{#each addButtons as btn}
			<button
				type="button"
				onclick={() => onAdd(btn.type)}
				class="rounded-lg border px-2.5 py-2 text-xs font-medium transition-colors {btn.colorClass}"
			>
				{btn.label}
			</button>
		{/each}
	</div>
</div>

<!-- Actions for selected segment -->
{#if selectedIndex !== null && selectedIndex < segments.length}
	<div class="mt-2 flex items-center gap-2">
		<button
			type="button"
			onclick={() => onMove(selectedIndex!, 'up')}
			disabled={selectedIndex === 0}
			class="rounded p-1.5 text-gray-500 hover:bg-gray-800 hover:text-white disabled:opacity-30"
			aria-label="Move left"
		>
			<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
			</svg>
		</button>
		<button
			type="button"
			onclick={() => onMove(selectedIndex!, 'down')}
			disabled={selectedIndex === segments.length - 1}
			class="rounded p-1.5 text-gray-500 hover:bg-gray-800 hover:text-white disabled:opacity-30"
			aria-label="Move right"
		>
			<svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
			</svg>
		</button>
		<button
			type="button"
			onclick={() => onDuplicate(selectedIndex!)}
			class="rounded px-2 py-1 text-xs text-gray-400 hover:bg-gray-800 hover:text-white"
		>
			Duplicate
		</button>
		<div class="flex-1"></div>
		<button
			type="button"
			onclick={() => onDelete(selectedIndex!)}
			class="rounded px-2 py-1 text-xs text-red-400 hover:bg-red-500/10"
		>
			Delete
		</button>
	</div>
{/if}
