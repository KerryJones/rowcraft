<script lang="ts">
	interface Props {
		label: string;
		value: string;
		unit?: string;
		trend?: 'up' | 'down' | 'flat' | null;
	}

	let { label, value, unit, trend = null }: Props = $props();

	const trendColors: Record<string, string> = {
		up: 'text-emerald-400',
		down: 'text-red-400',
		flat: 'text-gray-400'
	};

	const trendArrows: Record<string, string> = {
		up: '\u2191',
		down: '\u2193',
		flat: '\u2192'
	};
</script>

<div class="rounded-lg border border-gray-800 bg-gray-900 p-3">
	<div class="flex items-baseline gap-1">
		<span class="metric-value-sm text-white">{value}</span>
		{#if unit}
			<span class="metric-unit">{unit}</span>
		{/if}
		{#if trend}
			<span class="{trendColors[trend]} ml-1 text-sm font-medium">
				{trendArrows[trend]}
			</span>
		{/if}
	</div>
	<p class="metric-label mt-1">{label}</p>
</div>
