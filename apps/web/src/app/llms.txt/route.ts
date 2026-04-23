import { SITE_URL } from '@/lib/seo';

export function GET() {
  const content = `# RowCraft

> RowCraft is a free rowing workout platform for Concept2 ergometers. It provides structured interval workouts, multi-week training plans, and connects to Concept2 rowers via Bluetooth for real-time pace guidance.

## Key Pages

- [Workout Library](${SITE_URL}/workouts): Browse structured rowing workouts organized by training zone and category
- [Training Plans](${SITE_URL}/plans): Multi-week plans for beginner through advanced rowers
- [Workout of the Day](${SITE_URL}/workouts/wod): Daily rotating workout selection

## Workout Categories

RowCraft workouts are organized by heart rate training zone:

- Zone 1 Recovery: Light effort, active recovery sessions
- Zone 2 Aerobic: Steady state, base building, fat burning
- Zone 3 Tempo: Moderate intensity, lactate threshold development
- Zone 4 Threshold: High intensity interval training
- Zone 5 VO2max: Maximum effort sprint intervals

## Training Plan Collections

- Pete Plan: Popular community-developed progressive training program
- Wolverine Plan: Strength-endurance focused rowing plan
- British Rowing: Programs based on British Rowing methodology
- Return to Rowing: Gradual reintroduction plans for returning rowers
- Tests & Benchmarks: FTP tests, 2K race prep, benchmark workouts

## Features

- FTP-based pace targets personalized to each rower's fitness level
- Heart rate zone guidance for every workout segment
- Bluetooth connection to Concept2 PM5 monitor
- Custom workout builder with work, rest, warmup, and cooldown segments
- Coaching cues displayed during workouts

## About

Built by Kerry Jones. Free to use. Available at ${SITE_URL}
Contact: support@rowcraft.app

## Full Documentation

- [Full workout and plan listing](${SITE_URL}/llms-full.txt)
`;

  return new Response(content, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
