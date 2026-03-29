'use client';

import type { WorkoutSegment, SegmentType } from '@/lib/types';
import { cn } from '@/lib/utils/cn';
import { formatPace } from '@/lib/utils/format';
import { formatSegmentDuration } from '@/lib/utils/format';
import { computeCumulativeMinutes, expandSegments } from '@/lib/utils/workout';

const SEGMENT_COLORS: Record<SegmentType, string> = {
  work: '#3b82f6',
  rest: '#6b7280',
  warmup: '#22c55e',
  cooldown: '#eab308',
};

const TYPE_ABBREV: Record<SegmentType, string> = {
  work: 'W',
  rest: 'R',
  warmup: 'WU',
  cooldown: 'CD',
};

const BAR_GAP = 1.5;
const MIN_BAR_HEIGHT_FRACTION = 0.15;
const DEFAULT_PACE_MIN = 1000;
const DEFAULT_PACE_MAX = 1800;

interface WorkoutGraphProps {
  segments: WorkoutSegment[];
  variant?: 'card' | 'hero';
  selectedIndex?: number | null;
  onSelectSegment?: (index: number) => void;
  className?: string;
}

/**
 * Compute the effective duration of a segment in seconds (for proportional width).
 */
function getEffectiveDuration(seg: WorkoutSegment): number {
  const repeats = seg.repeat || 1;
  if (seg.duration_type === 'time') {
    return seg.duration_value * repeats;
  }
  if (seg.duration_type === 'distance') {
    const pacePerMeter = seg.target_split
      ? (seg.target_split.pace / 10) / 500
      : 0.24;
    return seg.duration_value * repeats * pacePerMeter;
  }
  // calories
  return (seg.duration_value * repeats / 15) * 60;
}

/**
 * Collect all non-null paces from segments.
 */
function getPaceRange(segments: WorkoutSegment[]): { paceMin: number; paceMax: number } {
  const paces: number[] = [];
  for (const seg of segments) {
    if (seg.target_split) {
      paces.push(seg.target_split.pace);
    }
  }
  if (paces.length === 0) {
    return { paceMin: DEFAULT_PACE_MIN, paceMax: DEFAULT_PACE_MAX };
  }
  const min = Math.min(...paces);
  const max = Math.max(...paces);
  // Add some padding so bars don't hit exact top/bottom
  const range = max - min || 200;
  return {
    paceMin: Math.max(0, min - range * 0.1),
    paceMax: max + range * 0.1,
  };
}

/**
 * Map a pace value to a normalized height (0-1) where faster (lower tenths) = taller.
 * Returns MIN_BAR_HEIGHT_FRACTION for segments with no pace.
 */
function paceToHeight(pace: number | null, paceMin: number, paceMax: number): number {
  if (pace === null) return MIN_BAR_HEIGHT_FRACTION;
  const range = paceMax - paceMin;
  if (range === 0) return 0.7;
  // Invert: lower pace = taller bar
  const normalized = 1 - (pace - paceMin) / range;
  return MIN_BAR_HEIGHT_FRACTION + normalized * (1 - MIN_BAR_HEIGHT_FRACTION);
}

/**
 * Generate Y-axis pace labels (2-3 labels). Since the axis is inverted (fast=top),
 * we pick evenly spaced paces between min and max.
 */
function getYAxisLabels(paceMin: number, paceMax: number): { pace: number; fraction: number }[] {
  const range = paceMax - paceMin;
  if (range === 0) {
    return [{ pace: paceMin, fraction: 0.5 }];
  }

  // Round to nice pace values (multiples of 50 tenths = 5 seconds)
  const roundTo = 50;
  const niceMin = Math.ceil(paceMin / roundTo) * roundTo;
  const niceMax = Math.floor(paceMax / roundTo) * roundTo;

  const labels: { pace: number; fraction: number }[] = [];

  if (niceMax - niceMin < roundTo) {
    // Very narrow range, just show midpoint
    const mid = Math.round((paceMin + paceMax) / 2 / roundTo) * roundTo;
    labels.push({ pace: mid, fraction: 1 - (mid - paceMin) / range });
  } else {
    // Pick 2-3 nice values
    const step = niceMax - niceMin <= roundTo * 2
      ? roundTo
      : Math.ceil((niceMax - niceMin) / 2 / roundTo) * roundTo;

    for (let p = niceMin; p <= niceMax; p += step) {
      const fraction = 1 - (p - paceMin) / range;
      labels.push({ pace: p, fraction });
    }
  }

  return labels;
}

/**
 * Generate X-axis minute markers.
 */
function getXAxisLabels(
  segments: WorkoutSegment[],
  totalDuration: number,
): { minute: number; fraction: number }[] {
  const markers = computeCumulativeMinutes(segments);
  const totalMinutes = markers[markers.length - 1]?.minute ?? 0;
  if (totalMinutes <= 0) return [];

  // Choose interval: every 1, 2, 5, or 10 minutes depending on total
  let interval: number;
  if (totalMinutes <= 5) interval = 1;
  else if (totalMinutes <= 15) interval = 2;
  else if (totalMinutes <= 40) interval = 5;
  else interval = 10;

  const labels: { minute: number; fraction: number }[] = [];
  for (let m = interval; m < totalMinutes; m += interval) {
    labels.push({ minute: m, fraction: m / totalMinutes });
  }
  return labels;
}

export function WorkoutGraph({
  segments,
  variant = 'card',
  selectedIndex,
  onSelectSegment,
  className,
}: WorkoutGraphProps) {
  if (segments.length === 0) {
    return (
      <div
        className={cn(
          'flex items-center justify-center rounded-lg border border-dashed border-gray-700 text-sm text-gray-500',
          variant === 'hero' ? 'h-[220px]' : 'h-[120px]',
          className,
        )}
      >
        Add segments
      </div>
    );
  }

  // Expand segments with repeat > 1 into individual interleaved bars
  const expandedSegments = expandSegments(segments);

  const isHero = variant === 'hero';
  const svgHeight = isHero ? 220 : 120;
  const paddingLeft = isHero ? 45 : 40;
  const paddingBottom = isHero ? 28 : 20;
  const paddingTop = 8;
  const paddingRight = 4;

  const chartWidth = 1000; // viewBox width
  const chartAreaLeft = paddingLeft;
  const chartAreaRight = chartWidth - paddingRight;
  const chartAreaWidth = chartAreaRight - chartAreaLeft;
  const chartAreaTop = paddingTop;
  const chartAreaBottom = svgHeight - paddingBottom;
  const chartAreaHeight = chartAreaBottom - chartAreaTop;

  // Compute bar layout using expanded segments
  const durations = expandedSegments.map(getEffectiveDuration);
  const totalDuration = durations.reduce((a, b) => a + b, 0);
  if (totalDuration === 0) return null;

  const totalGapWidth = BAR_GAP * (expandedSegments.length - 1);
  const availableBarWidth = chartAreaWidth - totalGapWidth;

  const { paceMin, paceMax } = getPaceRange(expandedSegments);
  const yLabels = getYAxisLabels(paceMin, paceMax);
  const xLabels = getXAxisLabels(expandedSegments, totalDuration);

  // Compute bar positions
  const bars: {
    x: number;
    y: number;
    width: number;
    height: number;
    segment: WorkoutSegment;
    index: number;
  }[] = [];

  let currentX = chartAreaLeft;
  for (let i = 0; i < expandedSegments.length; i++) {
    const seg = expandedSegments[i];
    const widthFraction = durations[i] / totalDuration;
    const barWidth = Math.max(2, widthFraction * availableBarWidth);
    const heightFraction = paceToHeight(
      seg.target_split?.pace ?? null,
      paceMin,
      paceMax,
    );
    const barHeight = heightFraction * chartAreaHeight;
    const barY = chartAreaBottom - barHeight;

    bars.push({
      x: currentX,
      y: barY,
      width: barWidth,
      height: barHeight,
      segment: seg,
      index: i,
    });

    currentX += barWidth + BAR_GAP;
  }

  const yLabelFontSize = isHero ? 10 : 9;
  const xLabelFontSize = isHero ? 10 : 9;
  const barLabelFontSize = 9;

  return (
    <svg
      viewBox={`0 0 ${chartWidth} ${svgHeight}`}
      preserveAspectRatio="none"
      className={cn('w-full', className)}
      style={{ height: svgHeight }}
      role="img"
      aria-label="Workout intensity graph"
    >
      {/* Y-axis labels (pace) */}
      {yLabels.map(({ pace, fraction }) => {
        const y = chartAreaTop + (1 - fraction) * chartAreaHeight;
        return (
          <g key={`y-${pace}`}>
            <line
              x1={chartAreaLeft}
              y1={y}
              x2={chartAreaRight}
              y2={y}
              stroke="#374151"
              strokeWidth={0.5}
              strokeDasharray="4,3"
            />
            <text
              x={paddingLeft - 4}
              y={y + 3}
              textAnchor="end"
              fill="#6b7280"
              fontSize={yLabelFontSize}
            >
              {formatPace(pace)}
            </text>
          </g>
        );
      })}

      {/* Baseline */}
      <line
        x1={chartAreaLeft}
        y1={chartAreaBottom}
        x2={chartAreaRight}
        y2={chartAreaBottom}
        stroke="#374151"
        strokeWidth={0.5}
      />

      {/* Bars */}
      {bars.map(({ x, y, width, height, segment, index }) => {
        const isSelected = selectedIndex === index;
        const isClickable = !!onSelectSegment;
        const color = SEGMENT_COLORS[segment.type];
        const barRadius = Math.min(3, width / 2);

        return (
          <g
            key={index}
            className={isClickable ? 'cursor-pointer' : undefined}
            onClick={isClickable ? () => onSelectSegment(index) : undefined}
            role={isClickable ? 'button' : undefined}
            tabIndex={isClickable ? 0 : undefined}
            onKeyDown={
              isClickable
                ? (e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      onSelectSegment(index);
                    }
                  }
                : undefined
            }
          >
            <rect
              x={x}
              y={y}
              width={width}
              height={height}
              rx={barRadius}
              ry={barRadius}
              fill={color}
              opacity={isClickable ? 0.9 : 1}
            >
              {isClickable && (
                <animate
                  attributeName="opacity"
                  values="0.9;0.7;0.9"
                  dur="0s"
                  begin="mouseover"
                  fill="freeze"
                />
              )}
            </rect>

            {/* Hover overlay for clickable bars */}
            {isClickable && (
              <rect
                x={x}
                y={y}
                width={width}
                height={height}
                rx={barRadius}
                ry={barRadius}
                fill="white"
                opacity={0}
                className="hover:opacity-10 transition-opacity"
              />
            )}

            {/* Selected ring */}
            {isSelected && (
              <rect
                x={x - 1.5}
                y={y - 1.5}
                width={width + 3}
                height={height + 3}
                rx={barRadius + 1}
                ry={barRadius + 1}
                fill="none"
                stroke="white"
                strokeWidth={2}
              />
            )}

            {/* Hero mode: type abbreviation + duration below bar */}
            {isHero && width > 30 && (
              <>
                <text
                  x={x + width / 2}
                  y={chartAreaBottom + 12}
                  textAnchor="middle"
                  fill="#9ca3af"
                  fontSize={barLabelFontSize}
                  fontWeight={500}
                >
                  {TYPE_ABBREV[segment.type]}
                </text>
                {width > 50 && (
                  <text
                    x={x + width / 2}
                    y={chartAreaBottom + 22}
                    textAnchor="middle"
                    fill="#6b7280"
                    fontSize={barLabelFontSize - 1}
                  >
                    {formatSegmentDuration(segment)}
                  </text>
                )}
              </>
            )}
          </g>
        );
      })}

      {/* X-axis minute markers */}
      {xLabels.map(({ minute, fraction }) => {
        const x = chartAreaLeft + fraction * chartAreaWidth;
        return (
          <g key={`x-${minute}`}>
            <line
              x1={x}
              y1={chartAreaBottom}
              x2={x}
              y2={chartAreaBottom + 4}
              stroke="#4b5563"
              strokeWidth={0.5}
            />
            <text
              x={x}
              y={chartAreaBottom + (isHero ? 14 : 12)}
              textAnchor="middle"
              fill="#6b7280"
              fontSize={xLabelFontSize}
            >
              {minute}m
            </text>
          </g>
        );
      })}
    </svg>
  );
}
