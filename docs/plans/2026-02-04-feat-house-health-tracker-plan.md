---
title: "feat: House Health Tracker"
type: feat
date: 2026-02-04
---

# feat: House Health Tracker

## Overview

Build a Rails 8 web app that gamifies house maintenance by tracking a "health score" for your home. Each room gets a score based on how recently its maintenance tasks have been completed, and scores decay over time. Two interfaces serve different purposes: a **kiosk dashboard** (`/dashboard`) for an always-on kitchen screen, and a **mobile quick-log** (`/`) for logging task completions from your phone. Live updates via Turbo Streams keep the kiosk in sync.

## Problem Statement / Motivation

Household cleaning is invisible work — there's no feedback loop for staying on top of it. This app creates that feedback loop by making cleanliness visible, quantified, and slightly gamified. The always-on kiosk display acts as a passive reminder, and the decay mechanic creates gentle urgency without nagging notifications.

## Proposed Solution

A single-user Rails 8 app with Tailwind CSS. No authentication. Scores are computed server-side in Ruby using a gradual decay curve. Turbo Streams over Action Cable (Solid Cable) push live updates when tasks are completed. The kiosk dashboard auto-refreshes every hour via a meta refresh tag to reflect time-based decay (scores typically change less than 2 points per hour).

## Technical Approach

### Architecture

```
┌─────────────────────────────────────────────────┐
│                   Rails 8 App                    │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Kiosk   │  │  Mobile  │  │   Management  │  │
│  │ /dashboard│  │    /     │  │   /rooms/*    │  │
│  │          │  │          │  │   /tasks/*    │  │
│  └────┬─────┘  └────┬─────┘  └───────┬───────┘  │
│       │              │                │          │
│       ▼              ▼                ▼          │
│  ┌─────────────────────────────────────────┐     │
│  │           Scoring Methods               │     │
│  │  Task#health_score → Room#score →       │     │
│  │  Room.house_score (simple avg)          │     │
│  └─────────────────────────────────────────┘     │
│       │                                          │
│       ▼                                          │
│  ┌─────────────────────────────────────────┐     │
│  │  Turbo Streams (Action Cable/Solid Cable)│    │
│  │  + Meta refresh (1hr) for decay updates  │    │
│  └─────────────────────────────────────────┘     │
│       │                                          │
│       ▼                                          │
│  ┌──────────┐                                    │
│  │  SQLite  │                                    │
│  └──────────┘                                    │
└─────────────────────────────────────────────────┘
```

### Data Model

```mermaid
erDiagram
    Room ||--o{ Task : "has many"
    Task ||--o{ Completion : "has many"

    Room {
        bigint id PK
        string name
        timestamps
    }

    Task {
        bigint id PK
        bigint room_id FK
        string name
        integer decay_period_days
        timestamps
    }

    Completion {
        bigint id PK
        bigint task_id FK
        timestamps
    }
```

**Key model decisions:**

- **Room** — Top-level entity (no House model needed for a single-user app).
- **Task** — Belongs to Room. `decay_period_days` is a positive integer, minimum 1. Never-completed tasks have a score of **0** — your score only goes up by doing work.
- **Completion** — Belongs to Task. Only the most recent `created_at` matters for scoring. Historical completions are kept for future trend features (v2). No separate `completed_at` needed — the record's creation *is* the completion.
- **House score** — Computed via `Room.house_score` class method (average of all room scores). No House model or table needed.

### Decay Formula

Use an **exponential decay** function that provides the gradual curve behavior:

```ruby
# score = 100 * e^(-k * t)
# where:
#   t = hours since last completion
#   k = decay constant derived from decay_period
#
# We calibrate k so that at exactly 1 decay_period,
# the score is at SCORE_AT_ONE_PERIOD (default 0.6 = 60%).
# At 2x decay_period, score is ~36.
# At 3x decay_period, score is ~22.

# Tuning constant: score at exactly 1 decay period (0.6 = 60%)
SCORE_AT_ONE_PERIOD = 0.6

def health_score
  return 0 if last_completed_at.nil?

  hours_elapsed = (Time.current - last_completed_at) / 1.hour
  decay_period_hours = decay_period_days * 24.0
  k = -Math.log(SCORE_AT_ONE_PERIOD) / decay_period_hours

  score = 100.0 * Math.exp(-k * hours_elapsed)
  score.round.clamp(0, 100)
end
```

**Score behavior examples (7-day decay task):**

| Time Since Completion | Score | Color  |
|----------------------|-------|--------|
| Just completed       | 100   | Green  |
| 3.5 days             | 77    | Green  |
| 7 days (1x period)   | 60    | Yellow |
| 10 days              | 48    | Yellow |
| 14 days (2x period)  | 36    | Red    |
| 21 days (3x period)  | 22    | Red    |

### Color System — Continuous HSL Gradient

Instead of three discrete color buckets, scores map to a **continuous color gradient** using HSL color space. The hue channel maps score 0–100 to hue 0–120:

- Score 0 → Hue 0 (red)
- Score 25 → Hue 30 (orange-red)
- Score 50 → Hue 60 (yellow)
- Score 75 → Hue 90 (yellow-green)
- Score 100 → Hue 120 (green)

```ruby
# app/helpers/score_color_helper.rb
module ScoreColorHelper
  def score_color(score)
    return "hsl(0, 70%, 45%)" if score.nil? || score <= 0

    hue = (score * 1.2).round.clamp(0, 120)
    "hsl(#{hue}, 70%, 45%)"
  end
end
```

Used as inline styles on room cards, score numbers, and the house score:

```erb
<div style="background-color: <%= score_color(room.score) %>">
```

This gives fine-grained visual feedback — you can see the difference between a room at 82 and one at 74 at a glance. The saturation (70%) and lightness (45%) values produce vibrant but readable colors; these can be tuned for kiosk vs mobile if needed.

### Scoring Rollup

```ruby
# Room#score = average of task scores (integer, rounded)
# Returns nil if room has no tasks
def score
  return nil if tasks.empty?
  (tasks.sum(&:health_score).to_f / tasks.size).round
end

# Room.house_score = average of all room scores (class method)
# Rooms with nil scores (no tasks) are excluded
# Uses includes(tasks: :completions) for eager loading to avoid N+1 queries
def self.house_score
  scored_rooms = Room.includes(tasks: :completions).select { |r| r.score.present? }
  return nil if scored_rooms.empty?

  (scored_rooms.sum(&:score).to_f / scored_rooms.size).round
end
```

### Implementation Phases

#### Phase 1: Foundation — Rails App + Data Model

Set up the Rails 8 app and core data model with scoring logic.

**Tasks:**

- [ ] `rails new house_health --css tailwind --database sqlite3`
  - Rails 8 includes Solid Cable by default (we'll use it for Turbo Streams)
  - We won't use Solid Queue (no background jobs needed)
- [ ] Generate models: `Room`, `Task`, `Completion`
  - `app/models/room.rb` — `has_many :tasks, dependent: :destroy`
  - `app/models/task.rb` — `belongs_to :room`, `has_many :completions, dependent: :destroy`
  - `app/models/completion.rb` — `belongs_to :task`
- [ ] Create migrations with proper indexes
  - `db/migrate/xxx_create_rooms.rb` — name (string)
  - `db/migrate/xxx_create_tasks.rb` — room_id (references), name (string), decay_period_days (integer); index on `room_id`
  - `db/migrate/xxx_create_completions.rb` — task_id (references); index on `task_id`, index on `[task_id, created_at]`
- [ ] Add model validations
  - Room: `name` presence
  - Task: `name` presence, `decay_period_days` numericality >= 1
- [ ] Implement scoring methods
  - `Task#health_score` — exponential decay formula (returns 0-100 integer)
  - `Task#last_completed_at` — `completions.maximum(:created_at)`
  - `Room#score` — average of task health scores (nil if no tasks)
  - `Room.house_score` — class method, average of all room scores (use `includes(tasks: :completions)` for eager loading)
- [ ] Create `ScoreColorHelper` with `score_color(score)` method
  - Maps score 0-100 to HSL hue 0-120 (red → yellow → green)
  - Returns CSS string like `hsl(90, 70%, 45%)`

#### Phase 2: Room & Task Management (CRUD)

Build the management UI first — users need to create rooms and tasks before anything else works.

**Tasks:**

- [ ] Create shared layout with conditional nav bar
  - `app/views/layouts/application.html.erb`
  - Nav: "Home" (`/`), "Dashboard" (`/dashboard`), "Rooms" (`/rooms`)
  - Hide nav on dashboard: `<%= render "shared/navbar" unless action_name == "dashboard" %>`
  - Include `turbo_refreshes_with method: :morph, scroll: :preserve`
  - Include viewport meta tag for mobile
  - Include `<meta http-equiv="refresh" content="3600">` only for dashboard action
- [ ] `RoomsController` — full CRUD
  - `app/controllers/rooms_controller.rb`
  - Routes: `resources :rooms`
  - Index: list all rooms with scores, edit/delete links
  - New/Edit: name field
  - Delete: cascade deletes tasks and completions
- [ ] `TasksController` — nested under rooms
  - `app/controllers/tasks_controller.rb`
  - Routes: `resources :rooms do; resources :tasks, except: [:index, :show]; end`
  - New/Edit: name field, decay_period_days (number input)
  - Delete: cascade deletes completions
- [ ] Room and task views
  - `app/views/rooms/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`
  - `app/views/tasks/new.html.erb`, `edit.html.erb`, `_form.html.erb`
- [ ] Empty state: rooms management index with no rooms shows "Add your first room" link

#### Phase 3: Mobile Quick-Log — `/`

Build the primary interface for logging task completions from your phone.

**Tasks:**

- [ ] `HomeController` with two actions (mobile and kiosk)
  - `app/controllers/home_controller.rb`
  - `index` action: mobile quick-log view
  - `dashboard` action: kiosk view
  - Routes: `root "home#index"` and `get "dashboard", to: "home#dashboard"`
  - Both actions load rooms with eager loading: `Room.includes(tasks: :completions)`
- [ ] `CompletionsController#create`
  - `app/controllers/completions_controller.rb`
  - Route: `resources :tasks, only: [] do; resources :completions, only: [:create]; end`
  - Creates Completion, responds with Turbo Stream
  - Done button uses `data-turbo-submits-with` to prevent double-taps
- [ ] Home view
  - `app/views/home/index.html.erb`
  - House score at top with color
  - List of rooms, each showing name, score, circular progress indicator
  - Tapping a room opens a modal showing its tasks
- [ ] Room tasks modal
  - `app/views/home/_room_modal.html.erb`
  - Modal takes up most of screen (leaves small margin to show context behind)
  - Room name and score at top
  - Tasks ordered by score ascending (most urgent first)
  - Each task: name, score, color dot, large "Done" button (44px+ tap target)
  - Close button (X) in top corner
  - Uses Turbo Frame with `data-turbo-frame="modal"` pattern
  - Empty state: room with no tasks shows "Add your first task" link (goes to `/rooms/:id/tasks/new`)
- [ ] Score update feedback
  - Small completion animation on "Done" button (checkmark flash or pulse)
  - Scores update in place via Turbo morph
  - User stays in modal to complete multiple tasks without re-opening
- [ ] Subscribe to Turbo Streams: `turbo_stream_from :house_scores`
- [ ] Empty state: no rooms shows inline "Add your first room" form
  - Simple form with room name field and "Add" button
  - After adding, user can tap room to add tasks via modal

#### Phase 4: Kiosk Dashboard — `/dashboard`

Build the always-on display for the kitchen screen. Uses the same `HomeController` as mobile (merged per DHH recommendation).

**Tasks:**

- [ ] Dashboard view (uses shared layout with nav hidden)
  - `app/views/home/dashboard.html.erb`
  - Large house score at top (big number, color-coded background)
  - Grid of room cards (`grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4`)
- [ ] Room card partial
  - `app/views/home/_room_card.html.erb`
  - Room name, large score number, color-coded background via `score_color` helper
  - Tappable — opens room tasks modal (same pattern as mobile)
- [ ] Room tasks modal (shared with mobile)
  - Reuse `_room_modal.html.erb` partial
  - Styled appropriately for larger kiosk screen (bigger tap targets, larger text)
  - Completing a task broadcasts refresh to all clients
  - User stays in modal to complete multiple tasks
- [ ] Subscribe to Turbo Streams: `turbo_stream_from :house_scores`
- [ ] Empty state: no rooms shows inline "Add your first room" form
  - Simple form with room name field and "Add" button
  - No navigation away — stays on dashboard

#### Phase 5: Polish

- [ ] Add `broadcasts_refreshes` to `Completion` model
- [ ] Ensure broadcasts work correctly
  - Completing a task updates both mobile and kiosk views instantly
  - Adding/editing/deleting rooms or tasks triggers refresh on both views
- [ ] Test responsive layouts
  - Dashboard: 1080p, 720p, tablet sizes
  - Mobile: 375px (iPhone SE), 414px (iPhone 14)
- [ ] Dark mode (optional): `prefers-color-scheme: dark` for kiosk night viewing

## Acceptance Criteria

### Functional Requirements

- [ ] Visiting `/` shows the mobile quick-log with room list and task completion buttons
- [ ] Visiting `/dashboard` shows the kiosk view with house score and color-coded room cards
- [ ] Completing a task creates a Completion record and updates scores in real-time on both views
- [ ] Task health scores decay over time using exponential decay with configurable `decay_period_days`
- [ ] Room scores are the average of their task scores
- [ ] House score is the average of room scores
- [ ] Rooms can be created, edited, and deleted
- [ ] Tasks can be created, edited, and deleted with custom decay periods
- [ ] Scores use a continuous HSL color gradient from red (0) through yellow (50) to green (100)
- [ ] Kiosk dashboard updates hourly to reflect time-based decay (user completions update instantly via Turbo)
- [ ] Room cards/rows are interactive — tapping opens a modal with room tasks and completion buttons
- [ ] Modal allows completing multiple tasks without closing (scores update in place)
- [ ] Completing a task shows a small completion animation before score updates
- [ ] Mobile room list shows circular progress indicators for scores
- [ ] Never-completed tasks have a score of 0
- [ ] Empty states show inline forms to add first room (no navigation away)

### Non-Functional Requirements

- [ ] Single-user, no authentication
- [ ] SQLite database (Rails 8 default)
- [ ] Solid Cable for Action Cable (no Redis)
- [ ] No background job infrastructure needed (meta refresh handles decay updates)
- [ ] Mobile-friendly (responsive Tailwind, 44px+ tap targets)
- [ ] Kiosk-friendly (fullscreen layout, no scrolling needed for reasonable room counts)

## Deployment

The app will be deployed on a **Digital Ocean droplet** and secured via **Tailscale**. This means:

- No public internet exposure — only devices on the Tailscale network can access the app
- No authentication needed — Tailscale provides the access control
- The kiosk (kitchen screen) and mobile devices must be on the same Tailscale network

This is appropriate for a single-user/household app where all devices are trusted.

## Dependencies & Risks

| Risk | Mitigation |
|------|-----------|
| Turbo Streams morph may cause flicker on kiosk | Test morphing behavior, fall back to targeted `replace` if needed |
| Hourly meta refresh causes brief page flash | Acceptable for kiosk; happens infrequently and user completions are pushed instantly via Turbo Streams |
| Exponential decay may feel too aggressive or too lenient | Calibration constant (0.6 at 1x period) can be tuned without changing the formula |
| Solid Cable with SQLite may have performance limits | Fine for single-user; monitor polling interval |
| Kiosk screen burn-in from static display | Consider dark mode or subtle animations in v2 |

## References & Research

### Brainstorm

- `docs/brainstorms/2026-02-04-house-health-tracker-brainstorm.md`

### Framework Documentation

- Turbo Streams Broadcasting: `broadcasts_to`, `broadcast_replace_to`, `turbo_stream_from`
- Solid Cable: Rails 8 default database-backed Action Cable adapter
- Meta refresh tag for periodic page reload (no background jobs needed)
- Rails request variants for device-specific templates (not used — using separate routes instead)
- Tailwind responsive: mobile-first with `md:`, `lg:`, `xl:` breakpoints
