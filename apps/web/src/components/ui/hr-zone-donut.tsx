import { HR_ZONE_COLORS, SEGMENT_REST_COLOR } from '@/lib/utils/segment-color';

interface HrZoneDonutProps {
	/** `{zone: seconds}` for zones 1-5. Empty/missing zones contribute nothing. */
	timeInZone: Record<number, number>;
	/** Outer diameter in pixels. */
	size?: number;
	/** Ring thickness in pixels. */
	strokeWidth?: number;
	className?: string;
}

/** Multi-section donut showing time-in-zone distribution. Renders a thin grey
 *  ring placeholder when no zone data exists. Each section's arc length is
 *  proportional to its share of total in-zone time. */
export function HrZoneDonut({
	timeInZone,
	size = 22,
	strokeWidth = 3,
	className,
}: HrZoneDonutProps) {
	const entries = Object.entries(timeInZone)
		.map(([k, v]) => ({ zone: Number(k), seconds: v }))
		.filter((e) => e.seconds > 0)
		.sort((a, b) => a.zone - b.zone);
	const total = entries.reduce((sum, e) => sum + e.seconds, 0);

	const radius = (size - strokeWidth) / 2;
	const cx = size / 2;
	const cy = size / 2;

	if (entries.length === 0 || total <= 0) {
		return (
			<svg
				className={className}
				width={size}
				height={size}
				viewBox={`0 0 ${size} ${size}`}
				aria-hidden="true"
			>
				<circle
					cx={cx}
					cy={cy}
					r={radius}
					fill="none"
					stroke="rgba(156, 163, 175, 0.4)"
					strokeWidth={1}
				/>
			</svg>
		);
	}

	// `pathLength=100` lets each section's dasharray be an exact percentage.
	// The rotate(-90) puts angle 0 at the top, so the donut starts at 12 o'clock
	// and grows clockwise. strokeDashoffset is *negated* because SVG's default
	// dash direction is counter-clockwise from the start — a negative offset
	// advances the start clockwise, which is what we want for stacking sections.
	let offset = 0;
	return (
		<svg
			className={className}
			width={size}
			height={size}
			viewBox={`0 0 ${size} ${size}`}
			aria-hidden="true"
		>
			<g transform={`rotate(-90 ${cx} ${cy})`}>
				{entries.map(({ zone, seconds }) => {
					const pct = (seconds / total) * 100;
					const dash = `${pct} ${100 - pct}`;
					const node = (
						<circle
							key={zone}
							cx={cx}
							cy={cy}
							r={radius}
							fill="none"
							stroke={HR_ZONE_COLORS[zone] ?? SEGMENT_REST_COLOR}
							strokeWidth={strokeWidth}
							pathLength={100}
							strokeDasharray={dash}
							strokeDashoffset={-offset}
						/>
					);
					offset += pct;
					return node;
				})}
			</g>
		</svg>
	);
}
