'use client';

import type { WorkoutSegment } from '@/lib/types';
import { isRestSegment } from '@/lib/types';
import { cn } from '@/lib/utils/cn';
import { formatSegmentDuration } from '@/lib/utils/format';
import { resolveIntensityToPace, getEffectiveFtp } from '@/lib/utils/ftp';
import { getSegmentDisplayColor } from '@/lib/utils/segment-color';
import { computeCumulativeMinutes, expandSegments } from '@/lib/utils/workout';

function segmentBarLabel(segment: WorkoutSegment): string {
  if (isRestSegment(segment)) return 'R';
  if (segment.target_hr_zone != null) return `Z${segment.target_hr_zone}`;
  return '';
}

const BAR_GAP = 1.5;
const MIN_BAR_HEIGHT_FRACTION = 0.15;

/** Fixed scale for absolute intensity mapping. */
const INTENSITY_FLOOR = 40;  // % FTP — below this, bar is at minimum height
const INTENSITY_CEIL = 130;  // % FTP — above this, bar is at maximum height

interface WorkoutGraphProps {
  segments: WorkoutSegment[];
  variant?: 'card' | 'hero';
  selectedIndex?: number | null;
  onSelectSegment?: (index: number) => void;
  className?: string;
  ftpWatts?: number | null;
}

/**
 * Compute the effective duration of a segment in seconds (for proportional width).
 */
function getEffectiveDuration(seg: WorkoutSegment, ftp: number): number {
  if (seg.duration_type === 'time') {
    return seg.duration_value;
  }
  if (seg.duration_type === 'distance') {
    let pacePerMeter = 0.24; // 2:00/500m default
    if (seg.target_intensity) {
      const pace = resolveIntensityToPace(seg.target_intensity, ftp);
      pacePerMeter = (pace / 10) / 500;
    }
    return seg.duration_value * pacePerMeter;
  }
  // calories
  return (seg.duration_value / 15) * 60;
}

/**
 * Map a segment's intensity to a height fraction (0-1) on a fixed absolute scale.
 * Higher intensity % = taller bar. Segments without intensity get minimum height.
 */
function intensityToHeight(segment: WorkoutSegment): number {
  if (!segment.target_intensity) return MIN_BAR_HEIGHT_FRACTION;
  const clamped = Math.max(INTENSITY_FLOOR, Math.min(INTENSITY_CEIL, segment.target_intensity));
  const normalized = (clamped - INTENSITY_FLOOR) / (INTENSITY_CEIL - INTENSITY_FLOOR);
  return MIN_BAR_HEIGHT_FRACTION + normalized * (1 - MIN_BAR_HEIGHT_FRACTION);
}

/**
 * Generate X-axis minute markers.
 */
function getXAxisLabels(
  segments: WorkoutSegment[],
  totalDuration: number,
  ftpWatts?: number,
): { minute: number; fraction: number }[] {
  const markers = computeCumulativeMinutes(segments, ftpWatts);
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
  ftpWatts,
}: WorkoutGraphProps) {
  const ftp = getEffectiveFtp(ftpWatts ?? null);
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
  const paddingLeft = 4;
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
  const durations = expandedSegments.map((s) => getEffectiveDuration(s, ftp));
  const totalDuration = durations.reduce((a, b) => a + b, 0);
  if (totalDuration === 0) return null;

  const totalGapWidth = BAR_GAP * (expandedSegments.length - 1);
  const availableBarWidth = chartAreaWidth - totalGapWidth;

  const xLabels = getXAxisLabels(expandedSegments, totalDuration, ftp);

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
    const heightFraction = intensityToHeight(seg);
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
        const color = getSegmentDisplayColor(segment);
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
                  {segmentBarLabel(segment)}
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
