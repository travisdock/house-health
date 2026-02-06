# House Health Tracker - Brainstorm

**Date:** 2026-02-04
**Status:** Ready for planning

## What We're Building

A web app that tracks the "health" of your house — how clean and well-maintained it is. The house gets an overall health score (e.g. 86/100), and each room gets its own score. Completing maintenance tasks (sweeping, vacuuming, scrubbing, etc.) restores health. Task health degrades over time using a gradual decay curve, so the longer you go without completing a task, the lower its contribution to the score.

The primary display is a **kiosk-style dashboard** designed to run on a kitchen screen, showing live-updating scores via Turbo Streams. Tasks are logged from a **simplified mobile view** on your phone.

## Why This Approach

- **Server-computed scores with Turbo Streams** — All decay/scoring logic lives in Ruby on the server. Turbo Streams over Action Cable push updates to the kiosk dashboard in real-time. This keeps the architecture simple (pure Rails/Hotwire) while delivering the live kiosk experience.
- **Gradual decay curve** — Linear decay penalizes small delays too harshly. A gradual curve (slow decay at first, accelerating as you pass the expected frequency) feels fair and motivating.
- **Customizable frequency per task** — Different tasks have different natural cadences. Wiping counters is daily, sweeping is every few days, mopping is weekly. Each task gets its own decay period.
- **Weighted room scoring** — Not all rooms are equal. The kitchen matters more than the guest room. Room weights let you tune the overall house score to reflect your priorities.
- **Task preset library** — Ships with a curated set of common household tasks and suggested decay periods to help get started quickly. Everything is fully customizable — add, remove, or tweak any task and its timing.

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Users | Single user | Personal tool, no auth complexity needed for v1 |
| Platform | Web app (Rails + Tailwind) | Familiar stack, runs on any device including kiosk |
| Scoring engine | Server-computed on page load | Simple, all logic in Ruby, no background jobs |
| Decay model | Gradual curve with custom frequency per task | Forgiving for small delays, steep for neglect |
| Room scoring | Average of task scores within room | Simple and intuitive |
| House scoring | Weighted average of room scores | Kitchen/bathroom weighted higher than guest room |
| Live updates | Turbo Streams via Action Cable | Instant kiosk updates when tasks are logged, periodic score refresh |
| Task presets | Seed library of common tasks, fully customizable | Helpful starting point without limiting flexibility |
| Mobile UX | Simplified quick-log view | Big tap targets, room list, log completions fast |
| Desktop/kiosk UX | Full dashboard with color-coded room cards | Designed for always-on kitchen display |
| Floorplan visualization | Deferred to v2 | Card/grid layout for v1, visual floorplan overlay later |
| History/trends | Deferred to v2 | Nice to have, not critical for v1 |
| Notifications | Deferred to v2 | Kiosk dashboard serves as the reminder for now |

## Core Concepts

### Data Model (Conceptual)

- **House** — The top-level entity. Has many rooms.
- **Room** — A physical room (Kitchen, Bathroom, Living Room). Has many tasks. Has a `weight` for house score calculation.
- **Task** — A recurring maintenance task (Sweep Floor, Wipe Counters). Belongs to a room. Has a `decay_period` (e.g. 1 day, 3 days, 7 days) that defines how quickly it degrades.
- **Completion** — A timestamp record of when a task was done. The most recent completion drives the current score.

### Decay Formula (Conceptual)

Each task's health is a function of `time_since_last_completion` and its `decay_period`:

- At completion: 100%
- At 1x decay_period: score starts dropping noticeably
- At 2x decay_period: score is significantly degraded
- At 3x+ decay_period: score approaches 0

The curve should be something like an exponential decay or logistic function — gentle at first, steep in the middle, flattening near zero. Exact formula to be tuned during implementation.

### Scoring Rollup

1. **Task score** = decay_function(time_since_last_completion, decay_period) -> 0-100
2. **Room score** = average(task scores in room) -> 0-100
3. **House score** = weighted_average(room scores, room weights) -> 0-100

### Two Interfaces

**Kiosk Dashboard (desktop/tablet):**
- Large house score displayed prominently
- Color-coded room cards (green/yellow/red) in a grid layout
- Each card shows room name, score, and the most urgent task
- Live updates via Turbo Streams — no manual refresh needed
- Designed for an always-on kitchen screen

**Mobile Quick-Log:**
- Simplified view optimized for phones
- List of rooms, tap into a room to see tasks
- Big tap targets to log task completions
- Minimal chrome — get in, log a task, get out

### Task Preset Library

Ships with common tasks organized by room type:

- **Kitchen:** Wipe counters (1 day), Sweep floor (3 days), Mop floor (7 days), Clean stovetop (7 days), Clean sink (3 days)
- **Bathroom:** Wipe counter (2 days), Clean toilet (7 days), Scrub shower (14 days), Mop floor (7 days)
- **Living Room:** Vacuum (7 days), Dust surfaces (14 days), Tidy up (3 days)
- **Bedroom:** Make bed (1 day), Vacuum (14 days), Dust (14 days), Change sheets (14 days)
- **General:** Take out trash (3 days), Take out recycling (7 days)

All presets are suggestions — users can customize decay periods, rename tasks, add new ones, or delete any they don't want.

## Open Questions

- **Decay formula specifics** — Exact mathematical function (exponential, logistic, piecewise). Should be tuned to feel right during implementation.
- **Task never completed** — What score should a task show if it's never been completed? 0? Or should it start at 100 and decay from the moment it's created?

## Out of Scope for v1

- Multi-user / household sharing
- History and trend charts
- Notifications / reminders
- Calendar integration
- Task scheduling / suggested routines
- Floorplan visualization / room layout overlay
- Gamification (streaks, achievements, badges)
