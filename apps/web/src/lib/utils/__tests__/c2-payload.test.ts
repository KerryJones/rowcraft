import { describe, expect, it } from 'vitest';
import {
  mapC2WorkoutType,
  buildHeartRateObject,
  buildSplits,
  buildIntervals,
  buildStrokeData,
  type C2Segment,
  type SplitJson,
  type TimeSampleJson,
} from '../c2-payload';

describe('mapC2WorkoutType', () => {
  it('returns JustRow for null workout type', () => {
    expect(mapC2WorkoutType(null, [])).toBe('JustRow');
  });

  it('maps single_distance to FixedDistanceSplits', () => {
    expect(mapC2WorkoutType('single_distance', [])).toBe('FixedDistanceSplits');
  });

  it('maps single_time to FixedTimeSplits', () => {
    expect(mapC2WorkoutType('single_time', [])).toBe('FixedTimeSplits');
  });

  it('maps intervals with distance segments to FixedDistanceInterval', () => {
    const segments: C2Segment[] = [
      { duration_type: 'distance', duration_value: 500 },
      { duration_type: 'time', duration_value: 60, is_rest: true },
    ];
    expect(mapC2WorkoutType('intervals', segments)).toBe('FixedDistanceInterval');
  });

  it('maps intervals with time segments to FixedTimeInterval', () => {
    const segments: C2Segment[] = [
      { duration_type: 'time', duration_value: 120 },
      { duration_type: 'time', duration_value: 60, is_rest: true },
    ];
    expect(mapC2WorkoutType('intervals', segments)).toBe('FixedTimeInterval');
  });

  it('maps intervals with calorie segments to FixedCalorieInterval', () => {
    const segments: C2Segment[] = [
      { duration_type: 'calories', duration_value: 50 },
    ];
    expect(mapC2WorkoutType('intervals', segments)).toBe('FixedCalorieInterval');
  });

  it('maps variable_intervals to VariableInterval', () => {
    expect(mapC2WorkoutType('variable_intervals', [])).toBe('VariableInterval');
  });
});

describe('buildHeartRateObject', () => {
  it('returns undefined when all values are null', () => {
    expect(buildHeartRateObject(null, null, null, null)).toBeUndefined();
  });

  it('builds object with all fields', () => {
    expect(buildHeartRateObject(150, 120, 175, 168)).toEqual({
      average: 150,
      min: 120,
      max: 175,
      ending: 168,
    });
  });

  it('omits null fields', () => {
    expect(buildHeartRateObject(150, null, null, null)).toEqual({
      average: 150,
    });
  });
});

describe('buildSplits', () => {
  const split: SplitJson = {
    segment_index: 0,
    distance: 500.3,
    time_ms: 105000,
    avg_pace: 1050,
    avg_stroke_rate: 28,
    avg_watts: 200,
    avg_heart_rate: 155,
    min_heart_rate: 140,
    max_heart_rate: 168,
    ending_heart_rate: 162,
    calories: 30,
  };

  it('converts split to C2 format', () => {
    const result = buildSplits([split]);
    expect(result).toHaveLength(1);

    const c2 = result[0];
    expect(c2.distance).toBe(500);          // rounded
    expect(c2.time).toBe(1050);             // ms -> tenths
    expect(c2.stroke_rate).toBe(28);
    expect(c2.calories_total).toBe(30);
    expect(c2.wattminutes_total).toBe(350); // 200W * 1.75min
    expect(c2.heart_rate).toEqual({
      average: 155,
      min: 140,
      max: 168,
      ending: 162,
    });
  });

  it('omits zero stroke rate and calories', () => {
    const emptySplit: SplitJson = {
      ...split,
      avg_stroke_rate: 0,
      avg_watts: 0,
      calories: 0,
      avg_heart_rate: undefined,
      min_heart_rate: undefined,
      max_heart_rate: undefined,
      ending_heart_rate: undefined,
    };
    const result = buildSplits([emptySplit]);
    const c2 = result[0];
    expect(c2.stroke_rate).toBeUndefined();
    expect(c2.calories_total).toBeUndefined();
    expect(c2.wattminutes_total).toBeUndefined();
    expect(c2.heart_rate).toBeUndefined();
  });
});

describe('buildIntervals', () => {
  it('builds intervals with rest from segment definitions', () => {
    const segments: C2Segment[] = [
      { duration_type: 'distance', duration_value: 500 },
      { duration_type: 'time', duration_value: 60, is_rest: true },
      { duration_type: 'distance', duration_value: 500 },
      { duration_type: 'time', duration_value: 60, is_rest: true },
    ];

    const splits: SplitJson[] = [
      { segment_index: 0, distance: 500, time_ms: 105000, avg_pace: 1050, avg_stroke_rate: 28, avg_watts: 200, calories: 30 },
      { segment_index: 1, distance: 20, time_ms: 60000, avg_pace: 0, avg_stroke_rate: 0, avg_watts: 0, calories: 0 },
      { segment_index: 2, distance: 500, time_ms: 108000, avg_pace: 1080, avg_stroke_rate: 27, avg_watts: 190, calories: 28 },
      { segment_index: 3, distance: 15, time_ms: 60000, avg_pace: 0, avg_stroke_rate: 0, avg_watts: 0, calories: 0 },
    ];

    const { intervals, totalRestTime, totalRestDistance } = buildIntervals(splits, segments);
    expect(intervals).toHaveLength(2);

    // First work interval
    expect(intervals[0].type).toBe('distance');
    expect(intervals[0].distance).toBe(500);
    expect(intervals[0].rest_time).toBe(600); // 60000ms -> 600 tenths

    // Second work interval
    expect(intervals[1].type).toBe('distance');
    expect(intervals[1].distance).toBe(500);
    expect(intervals[1].rest_time).toBe(600);

    // Rest totals
    expect(totalRestTime).toBe(1200); // 2 x 600 tenths
    expect(totalRestDistance).toBe(35); // 20 + 15
  });

  it('skips rest-only splits', () => {
    const segments: C2Segment[] = [
      { duration_type: 'time', duration_value: 120 },
      { duration_type: 'time', duration_value: 60, is_rest: true },
    ];

    const splits: SplitJson[] = [
      { segment_index: 0, distance: 500, time_ms: 120000, avg_pace: 1050, avg_stroke_rate: 28, avg_watts: 200, calories: 30 },
      { segment_index: 1, distance: 10, time_ms: 60000, avg_pace: 0, avg_stroke_rate: 0, avg_watts: 0, calories: 0 },
    ];

    const { intervals } = buildIntervals(splits, segments);
    expect(intervals).toHaveLength(1);
    expect(intervals[0].type).toBe('time');
  });

  it('uses segment definition for rest when no rest split exists', () => {
    const segments: C2Segment[] = [
      { duration_type: 'distance', duration_value: 500 },
      { duration_type: 'time', duration_value: 60, is_rest: true },
    ];

    const splits: SplitJson[] = [
      { segment_index: 0, distance: 500, time_ms: 105000, avg_pace: 1050, avg_stroke_rate: 28, avg_watts: 200, calories: 30 },
      // No split for rest segment
    ];

    const { intervals } = buildIntervals(splits, segments);
    expect(intervals[0].rest_time).toBe(600); // 60s * 10
  });

  it('sets rest_time to 0 when no rest segment follows', () => {
    const segments: C2Segment[] = [
      { duration_type: 'distance', duration_value: 500 },
    ];

    const splits: SplitJson[] = [
      { segment_index: 0, distance: 500, time_ms: 105000, avg_pace: 1050, avg_stroke_rate: 28, avg_watts: 200, calories: 30 },
    ];

    const { intervals } = buildIntervals(splits, segments);
    expect(intervals[0].rest_time).toBe(0);
  });

  it('forwards ending_heart_rate into each work interval heart_rate.ending', () => {
    const segments: C2Segment[] = [
      { duration_type: 'time', duration_value: 120 },
      { duration_type: 'time', duration_value: 60, is_rest: true },
      { duration_type: 'time', duration_value: 120 },
      { duration_type: 'time', duration_value: 60, is_rest: true },
    ];

    const splits: SplitJson[] = [
      {
        segment_index: 0, distance: 500, time_ms: 120000, avg_pace: 1200,
        avg_stroke_rate: 28, avg_watts: 200, calories: 30,
        avg_heart_rate: 145, min_heart_rate: 130, max_heart_rate: 160, ending_heart_rate: 158,
      },
      {
        segment_index: 1, distance: 10, time_ms: 60000, avg_pace: 0,
        avg_stroke_rate: 0, avg_watts: 0, calories: 0,
      },
      {
        segment_index: 2, distance: 500, time_ms: 120000, avg_pace: 1210,
        avg_stroke_rate: 28, avg_watts: 195, calories: 28,
        avg_heart_rate: 152, min_heart_rate: 142, max_heart_rate: 168, ending_heart_rate: 166,
      },
      {
        segment_index: 3, distance: 10, time_ms: 60000, avg_pace: 0,
        avg_stroke_rate: 0, avg_watts: 0, calories: 0,
      },
    ];

    const { intervals } = buildIntervals(splits, segments);
    expect(intervals).toHaveLength(2);
    expect(intervals[0].heart_rate).toEqual({
      average: 145,
      min: 130,
      max: 160,
      ending: 158,
    });
    expect(intervals[1].heart_rate).toEqual({
      average: 152,
      min: 142,
      max: 168,
      ending: 166,
    });
  });
});

describe('buildStrokeData', () => {
  it('converts time samples to C2 stroke format', () => {
    const samples: TimeSampleJson[] = [
      { t: 1000, d: 5.2, p: 1050, spm: 28, hr: 145, si: 0 },
      { t: 2000, d: 10.5, p: 1040, spm: 29, si: 0 },
    ];

    const result = buildStrokeData(samples);
    expect(result).toHaveLength(2);

    // First sample
    expect(result[0].t).toBe(10);    // 1000ms -> 10 tenths
    expect(result[0].d).toBe(52);    // 5.2m -> 52 decimeters
    expect(result[0].p).toBe(1050);
    expect(result[0].spm).toBe(28);
    expect(result[0].hr).toBe(145);

    // Second sample — no HR
    expect(result[1].t).toBe(20);
    expect(result[1].d).toBe(105);
    expect(result[1].hr).toBeUndefined();
  });
});
