export type FeatureSupport = 'yes' | 'no' | 'partial';

export interface Feature {
  name: string;
  rowcraft: FeatureSupport;
  competitor: FeatureSupport;
  rowcraftNote?: string;
  competitorNote?: string;
}

export interface Competitor {
  slug: string;
  name: string;
  tagline: string;
  website: string;
  pricing: string;
  priceMonthly: number;
  metaTitle: string;
  metaDescription: string;
  intro: string;
  features: Feature[];
  competitorStrengths: string[];
  rowcraftStrengths: string[];
  verdict: string;
  bestFor: string;
  rowcraftBestFor: string;
  lastUpdated: string;
}

const competitors: Competitor[] = [
  {
    slug: 'ergdata',
    name: 'ErgData',
    tagline: "Concept2's official companion app for PM5 data logging.",
    website: 'https://www.concept2.com/ergdata',
    pricing: 'Free',
    priceMonthly: 0,
    metaTitle: 'RowCraft vs ErgData — Honest Feature Comparison (2026)',
    metaDescription:
      'An honest comparison of RowCraft and ErgData. Both are free — ErgData is the official Concept2 data logger, RowCraft adds structured workouts, training plans, and pace guidance.',
    intro:
      "ErgData is Concept2's official companion app — the one most rowers install first. It connects to your PM5 via Bluetooth, displays real-time data, and syncs workouts to the Concept2 Logbook. RowCraft also connects to the PM5, but takes a different approach: instead of just recording data, it provides structured workouts with pace targets and multi-week training plans. Both apps are completely free. Here's how they compare.",
    features: [
      { name: 'PM5 Bluetooth connection', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Real-time pace, stroke rate, HR', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Concept2 Logbook sync', rowcraft: 'yes', competitor: 'yes', competitorNote: 'Native integration' },
      { name: 'Structured interval workouts', rowcraft: 'yes', competitor: 'partial', competitorNote: 'Basic intervals only' },
      { name: 'Workout library (130+)', rowcraft: 'yes', competitor: 'no' },
      { name: 'Multi-week training plans', rowcraft: 'yes', competitor: 'no' },
      { name: 'FTP-based pace targets', rowcraft: 'yes', competitor: 'no' },
      { name: 'Heart rate zone guidance', rowcraft: 'yes', competitor: 'partial', competitorNote: 'Zone display only' },
      { name: 'Custom workout builder', rowcraft: 'yes', competitor: 'partial', competitorNote: 'Basic interval setup' },
      { name: 'Strava export', rowcraft: 'no', competitor: 'yes' },
      { name: 'Apple Watch support', rowcraft: 'no', competitor: 'yes' },
      { name: 'Web app', rowcraft: 'yes', competitor: 'no' },
      { name: 'Free to use', rowcraft: 'yes', competitor: 'yes' },
    ],
    competitorStrengths: [
      "As Concept2's official app, ErgData has the deepest Logbook integration — your workouts sync natively and appear as verified entries.",
      'ErgData supports Strava and Garmin Connect export out of the box, which RowCraft does not offer yet.',
      'Apple Watch support lets you see heart rate data on your wrist during workouts.',
      "If you just need to log meters and sync to Concept2, ErgData does exactly that with zero setup.",
    ],
    rowcraftStrengths: [
      "RowCraft includes 130+ structured workouts and multi-week training plans. ErgData is a data logger — it records what you do but doesn't guide what to do.",
      'Every RowCraft workout has FTP-based pace targets shown as minutes per 500m, so you know exactly how hard to pull for each interval.',
      "RowCraft's workout builder lets you design intervals with specific work/rest durations, target intensities, and stroke rate guidance — not just basic time or distance intervals.",
      'RowCraft has a full web app for browsing workouts, building custom sessions, and managing training plans from your computer.',
    ],
    verdict:
      "ErgData is the best free data logger for Concept2 rowers — it does one thing well. RowCraft is for rowers who want structured training guidance on top of data logging. If you already know what workout to do and just need to record it, ErgData is great. If you want someone to tell you what to do and keep you on pace, that's what RowCraft is built for. Both are free, so there's no reason not to try both.",
    bestFor: 'Rowers who want a simple, reliable data logger with native Concept2 Logbook sync.',
    rowcraftBestFor: 'Rowers who want structured workouts, training plans, and pace guidance — not just data logging.',
    lastUpdated: '2026-04-23',
  },
  {
    slug: 'exr',
    name: 'EXR',
    tagline: 'Gamified virtual rowing with 3D worlds and social racing.',
    website: 'https://exrgame.com',
    pricing: '$15/mo',
    priceMonthly: 15,
    metaTitle: 'RowCraft vs EXR — Honest Feature Comparison (2026)',
    metaDescription:
      'An honest comparison of RowCraft and EXR. EXR offers virtual 3D worlds and social racing for $15/mo. RowCraft is free and focuses on structured training with pace guidance.',
    intro:
      "EXR is the \"Zwift for rowers\" — a gamified virtual rowing experience where your real strokes move an avatar through 3D worlds. It's built around motivation: racing, scenery, leaderboards. RowCraft takes the opposite approach, focusing on structured training with pace targets and progressive plans. EXR costs $15/mo, RowCraft is free. They solve different problems, and this comparison will help you figure out which one fits how you train.",
    features: [
      { name: 'PM5 Bluetooth connection', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Real-time pace, stroke rate, HR', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Concept2 Logbook sync', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Structured interval workouts', rowcraft: 'yes', competitor: 'yes', competitorNote: '100+ workouts' },
      { name: 'Multi-week training plans', rowcraft: 'yes', competitor: 'yes' },
      { name: 'FTP-based pace targets', rowcraft: 'yes', competitor: 'no' },
      { name: 'Heart rate zone guidance', rowcraft: 'yes', competitor: 'partial' },
      { name: 'Custom workout builder', rowcraft: 'yes', competitor: 'no' },
      { name: 'Virtual 3D scenery', rowcraft: 'no', competitor: 'yes' },
      { name: 'Multiplayer racing', rowcraft: 'no', competitor: 'yes' },
      { name: 'Ghost boat (race your PR)', rowcraft: 'no', competitor: 'yes' },
      { name: 'Leaderboards & challenges', rowcraft: 'no', competitor: 'yes' },
      { name: 'Web app', rowcraft: 'yes', competitor: 'yes', competitorNote: 'Windows & macOS' },
      { name: 'Free to use', rowcraft: 'yes', competitor: 'no', competitorNote: '$15/mo after trial' },
    ],
    competitorStrengths: [
      'EXR turns indoor rowing into a game. You row through 3D virtual worlds, race other rowers in real time, and unlock gear for your avatar. If motivation is your problem, EXR solves it.',
      'Multiplayer racing and ghost boats let you compete against others or your own personal bests, adding a competitive edge to every session.',
      'Daily, weekly, and monthly challenges with global leaderboards keep engagement high.',
      'Broad platform support including Apple TV, Windows, and macOS — you can row with a big screen in front of you.',
    ],
    rowcraftStrengths: [
      "RowCraft is free. EXR costs $15/mo. If you're rowing consistently, that's $180/yr.",
      "RowCraft's training is built around pace-per-500m targets derived from your FTP. Every interval tells you exactly how hard to pull. EXR's workouts exist but aren't structured around a personal fitness benchmark.",
      "RowCraft's custom workout builder lets you design any interval session you want. EXR's workouts are pre-built.",
      "RowCraft focuses on making you a better rower through progressive, structured training. EXR focuses on making rowing more fun. Different goals.",
    ],
    verdict:
      "EXR and RowCraft solve different problems. EXR is the best choice if you struggle with motivation and want rowing to feel like a game — the virtual worlds, racing, and social features are genuinely engaging. RowCraft is the better choice if you want structured training that makes you faster — pace targets, FTP-based programming, and progressive training plans. If you can afford EXR and motivation is your bottleneck, it's worth the subscription. If you want free, structured training, RowCraft is built for that.",
    bestFor: 'Rowers who find indoor rowing boring and want gamification, virtual scenery, and social competition.',
    rowcraftBestFor: 'Rowers who want structured, pace-based training that progressively builds fitness — for free.',
    lastUpdated: '2026-04-23',
  },
  {
    slug: 'asensei',
    name: 'Asensei',
    tagline: 'AI-powered real-time coaching for rowing technique.',
    website: 'https://asensei.com',
    pricing: '$20/mo',
    priceMonthly: 20,
    metaTitle: 'RowCraft vs Asensei — Honest Feature Comparison (2026)',
    metaDescription:
      'An honest comparison of RowCraft and Asensei. Asensei offers AI form coaching for $20/mo (iOS only). RowCraft is free with structured workouts and training plans on both Android and web.',
    intro:
      "Asensei is the only rowing app that coaches your technique in real time. It uses your phone's camera and PM5 data to analyze your stroke and give in-the-moment feedback. RowCraft doesn't do form coaching — it focuses on what to row and how hard, with FTP-based pace targets and structured training plans. Asensei costs $20/mo and is iOS only. RowCraft is free and runs on Android and web. They're more complementary than competitive.",
    features: [
      { name: 'PM5 Bluetooth connection', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Real-time pace, stroke rate, HR', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Concept2 Logbook sync', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Structured interval workouts', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Multi-week training plans', rowcraft: 'yes', competitor: 'yes', competitorNote: 'Coach-led programs' },
      { name: 'FTP-based pace targets', rowcraft: 'yes', competitor: 'partial', competitorNote: 'Coach sets targets' },
      { name: 'Heart rate zone guidance', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Custom workout builder', rowcraft: 'yes', competitor: 'no' },
      { name: 'Real-time form coaching', rowcraft: 'no', competitor: 'yes' },
      { name: 'AI technique analysis', rowcraft: 'no', competitor: 'yes' },
      { name: 'Coach-led video programs', rowcraft: 'no', competitor: 'yes' },
      { name: 'Android support', rowcraft: 'yes', competitor: 'no' },
      { name: 'Web app', rowcraft: 'yes', competitor: 'no' },
      { name: 'Free to use', rowcraft: 'yes', competitor: 'no', competitorNote: '$20/mo' },
    ],
    competitorStrengths: [
      "Asensei's real-time form coaching is unique. It watches your rowing via phone camera and machine data, then gives in-the-moment feedback on technique. No other app does this.",
      'Programs are designed by world-class coaches including Olympic gold medalist Eric Murray and Shane Farmer from Dark Horse Rowing.',
      'If you row without a coach and want to improve technique, Asensei fills a gap that no amount of workout programming can replace.',
      'Stroke-by-stroke analysis shows exactly where in the drive you lose power or break form.',
    ],
    rowcraftStrengths: [
      "RowCraft is free. Asensei costs $20/mo ($240/yr) — the most expensive app in this space.",
      'RowCraft runs on Android and web. Asensei is iOS only — if you have an Android phone, Asensei is not an option.',
      "RowCraft's workout builder lets you create any interval session. Asensei's workouts are pre-built by coaches — you follow their programs.",
      "RowCraft's FTP-based pace targets personalize every workout to your current fitness. You set your FTP and every target adjusts automatically.",
    ],
    verdict:
      "Asensei and RowCraft are complementary more than competitive. Asensei coaches your technique — how you row. RowCraft structures your training — what you row and how hard. If you're an iOS user who wants form feedback and can afford the subscription, Asensei is genuinely valuable. If you're on Android, want free structured training, or already have decent technique, RowCraft covers your needs. Some rowers use both: Asensei for technique sessions, RowCraft for their daily structured training.",
    bestFor: 'iOS rowers who want real-time form coaching and technique improvement from expert coaches.',
    rowcraftBestFor: 'Rowers on any platform who want free, self-directed structured training with personalized pace targets.',
    lastUpdated: '2026-04-23',
  },
  {
    slug: 'kinomap',
    name: 'KinoMap',
    tagline: 'Real-world video routes for cycling, running, and rowing.',
    website: 'https://www.kinomap.com',
    pricing: '$12/mo',
    priceMonthly: 12,
    metaTitle: 'RowCraft vs KinoMap — Honest Feature Comparison (2026)',
    metaDescription:
      'An honest comparison of RowCraft and KinoMap. KinoMap offers scenic video routes for $12/mo. RowCraft is free and focused on structured rowing workouts with pace guidance.',
    intro:
      "KinoMap is a multi-sport indoor training app with over 50,000 real-world filmed video routes. You row along actual waterways and the video speed matches your pace. It covers cycling, running, and rowing — but rowing is a secondary focus. RowCraft is built exclusively for rowing with structured workouts and FTP-based pace targets. KinoMap costs $12/mo, RowCraft is free. If you're choosing between scenic distraction and structured training, here's how they stack up.",
    features: [
      { name: 'PM5 Bluetooth connection', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Real-time pace, stroke rate, HR', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Concept2 Logbook sync', rowcraft: 'yes', competitor: 'partial', competitorNote: 'Data export available' },
      { name: 'Structured interval workouts', rowcraft: 'yes', competitor: 'partial', competitorNote: 'Basic sessions' },
      { name: 'Multi-week training plans', rowcraft: 'yes', competitor: 'no' },
      { name: 'FTP-based pace targets', rowcraft: 'yes', competitor: 'no' },
      { name: 'Heart rate zone guidance', rowcraft: 'yes', competitor: 'partial' },
      { name: 'Custom workout builder', rowcraft: 'yes', competitor: 'no' },
      { name: 'Real-world video routes', rowcraft: 'no', competitor: 'yes', competitorNote: '50,000+ routes' },
      { name: 'Multi-sport (bike, run, row)', rowcraft: 'no', competitor: 'yes' },
      { name: 'Multiplayer sessions', rowcraft: 'no', competitor: 'yes' },
      { name: 'Android support', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Web app', rowcraft: 'yes', competitor: 'partial', competitorNote: 'Browser display only' },
      { name: 'Free to use', rowcraft: 'yes', competitor: 'no', competitorNote: '$12/mo after trial' },
    ],
    competitorStrengths: [
      'KinoMap has 50,000+ real-world filmed video routes. You row along actual waterways and rivers — the video speed matches your pace.',
      "Multi-sport support means one subscription covers cycling, running, and rowing. If your household uses multiple machines, that's good value.",
      'Multiplayer sessions let you row alongside friends or strangers in real time on the same route.',
      'The sheer visual variety makes long steady-state sessions more tolerable.',
    ],
    rowcraftStrengths: [
      "RowCraft is free. KinoMap costs $12/mo ($144/yr).",
      "RowCraft is built specifically for rowing. KinoMap is primarily a cycling app — rowing is a secondary use case with a smaller video library and less rowing-specific training features.",
      'RowCraft has structured multi-week training plans with FTP-based pace targets. KinoMap has scenic routes but no progressive training programming for rowers.',
      "RowCraft's workout builder lets you design custom interval sessions. KinoMap's structured workouts can't be combined with scenic video routes.",
    ],
    verdict:
      "KinoMap and RowCraft serve different needs. KinoMap is scenic distraction — it makes long rows more enjoyable by putting you on a virtual river. RowCraft is structured training — it tells you what to do and keeps you on pace. If you hate staring at the wall during 60-minute steady-state rows, KinoMap helps with that. If you want to get faster through progressive, structured training, RowCraft is the better tool. KinoMap is also best if you use multiple machines (bike + rower) and want one app for everything.",
    bestFor: 'Rowers who want scenic video routes to make long sessions enjoyable, or multi-sport households.',
    rowcraftBestFor: 'Rowers who want structured, rowing-specific training with personalized pace targets — for free.',
    lastUpdated: '2026-04-23',
  },
  {
    slug: 'ergzone',
    name: 'ErgZone',
    tagline: 'Structured erg workouts with smart pacing and a coach marketplace.',
    website: 'https://www.erg.zone',
    pricing: '$5/mo',
    priceMonthly: 5,
    metaTitle: 'RowCraft vs ErgZone — Honest Feature Comparison (2026)',
    metaDescription:
      'An honest comparison of RowCraft and ErgZone. ErgZone offers smart pacing and a coach marketplace for $5/mo. RowCraft is free with built-in training plans and FTP-based pace guidance.',
    intro:
      "ErgZone is the closest competitor to RowCraft in philosophy — both are training-focused apps for serious rowers. ErgZone offers smart benchmark-based pacing, a coach marketplace, and integrations with Strava and TrainingPeaks. RowCraft uses FTP-based pace targets, includes built-in training plans, and is completely free. ErgZone's premium tier costs $5/mo. If you're choosing between two structured training apps, here's an honest look at the trade-offs.",
    features: [
      { name: 'PM5 Bluetooth connection', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Real-time pace, stroke rate, HR', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Concept2 Logbook sync', rowcraft: 'yes', competitor: 'yes', competitorNote: 'Verified entries' },
      { name: 'Structured interval workouts', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Multi-week training plans', rowcraft: 'yes', competitor: 'yes', competitorNote: 'Via coach marketplace' },
      { name: 'FTP-based pace targets', rowcraft: 'yes', competitor: 'partial', competitorNote: 'Benchmark-based pacing' },
      { name: 'Heart rate zone guidance', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Custom workout builder', rowcraft: 'yes', competitor: 'yes' },
      { name: 'Coach marketplace', rowcraft: 'no', competitor: 'yes' },
      { name: 'Strava integration', rowcraft: 'no', competitor: 'yes', competitorNote: 'Premium feature' },
      { name: 'TrainingPeaks sync', rowcraft: 'no', competitor: 'yes', competitorNote: 'Premium feature' },
      { name: 'Force curve display', rowcraft: 'no', competitor: 'yes' },
      { name: 'Multi-erg sessions', rowcraft: 'no', competitor: 'yes', competitorNote: 'Connect 2–3 ergs' },
      { name: 'Web app', rowcraft: 'yes', competitor: 'yes', competitorNote: 'Dashboard only' },
      { name: 'Free to use', rowcraft: 'yes', competitor: 'partial', competitorNote: 'Free tier; $5/mo for premium' },
    ],
    competitorStrengths: [
      "ErgZone's coach marketplace connects you with real rowing coaches who create custom programming — including well-known coaches like Coach Bergenroth.",
      'Smart interval pacing suggests target splits based on your benchmark times (1K, 2K, 5K), which is a different but valid approach to personalization.',
      'Strava and TrainingPeaks integration lets you connect ErgZone to a broader training ecosystem.',
      'Force curve display and SPI (Stroke Power Index) give advanced rowers deeper stroke-level analytics.',
      'Multi-erg mode connects 2–3 Concept2 ergs simultaneously for team training.',
    ],
    rowcraftStrengths: [
      'RowCraft is completely free — no tiers, no premium features behind a paywall. ErgZone has a free tier, but Strava sync, TrainingPeaks, and other features require $5/mo.',
      "RowCraft's training plans are built-in and included. ErgZone's plans come through a coach marketplace that may cost extra on top of the subscription.",
      "RowCraft uses FTP to automatically calculate pace targets for every workout. You set your FTP once and every target adjusts. ErgZone's benchmark-based pacing requires you to have recent test results for each distance.",
      "RowCraft's full web app lets you browse workouts, build sessions, and manage plans from your computer. ErgZone's web access is a dashboard, not the full app experience.",
    ],
    verdict:
      "ErgZone is the closest competitor to RowCraft in philosophy — both are training-focused, structured workout apps for serious rowers. The key differences: ErgZone has a coach marketplace and third-party integrations (Strava, TrainingPeaks) that RowCraft doesn't. RowCraft has built-in training plans and is completely free. If you want coaching from a named coach or need Strava/TrainingPeaks sync, ErgZone is worth the subscription. If you want structured training with FTP-based pacing at no cost, RowCraft delivers that out of the box.",
    bestFor: 'Serious rowers who want coach-created programs, Strava/TrainingPeaks sync, and advanced analytics.',
    rowcraftBestFor: 'Rowers who want structured, FTP-based training with built-in plans — completely free.',
    lastUpdated: '2026-04-23',
  },
];

export function getAllComparisons(): Competitor[] {
  return competitors;
}

export function getComparisonBySlug(slug: string): Competitor | undefined {
  return competitors.find((c) => c.slug === slug);
}

export function pricingLabel(pricing: string): string {
  return pricing === 'Free' ? 'Both free' : `Free vs ${pricing}`;
}
