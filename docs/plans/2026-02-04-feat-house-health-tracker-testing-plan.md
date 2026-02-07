---
title: "House Health Tracker — TDD Testing Plan"
type: feat
date: 2026-02-04
---

# House Health Tracker — TDD Testing Plan

Write tests **before** implementation for each sub-phase. The cycle is: write failing tests, implement until green, refactor. Tests use Rails default Minitest with fixtures.

---

## Phase 1: Foundation — Models & Scoring

This is the most test-heavy phase since the scoring logic is the core of the app. Every subsequent phase depends on these models being correct.

### 1A: Model Validations & Associations

**File: `test/models/room_test.rb`**

- `test "room requires a name"` — blank name is invalid
- `test "room has many tasks"` — associating tasks works
- `test "destroying a room destroys its tasks"` — dependent: :destroy cascades

**File: `test/models/task_test.rb`**

- `test "task requires a name"` — blank name is invalid
- `test "task requires decay_period_days"` — nil is invalid
- `test "task decay_period_days must be at least 1"` — 0 is invalid, 1 is valid
- `test "task belongs to a room"` — association works
- `test "task has many completions"` — association works
- `test "destroying a task destroys its completions"` — dependent: :destroy cascades

**File: `test/models/completion_test.rb`**

- `test "completion belongs to a task"` — association works

### 1B: Task Scoring (Decay Formula)

**Note on time-dependent tests:** All decay tests must use `travel_to` to freeze time at the start of the test. Use approximate assertions (e.g., `assert_in_delta 60, score, 1`) rather than exact equality to avoid flakiness from rounding or timing edge cases.

**File: `test/models/task_test.rb`** (continued)

- `test "health_score is 0 when task has never been completed"` — no completions exist, score is 0
- `test "health_score is 100 immediately after completion"` — complete a task just now, score is 100
- `test "health_score decays over time for a daily task"` — complete a 1-day task, travel_to 12 hours later, score should be roughly 77; travel_to 24 hours later, score should be roughly 60
- `test "health_score decays over time for a weekly task"` — complete a 7-day task, travel_to 3.5 days later, score should be roughly 77; travel_to 7 days later, score should be roughly 60
- `test "health_score approaches 0 at 3x decay period"` — complete a 7-day task, travel_to 21 days, score should be near 22
- `test "health_score never goes below 0"` — travel_to a very long time (e.g. 365 days), score is 0 not negative
- `test "health_score never exceeds 100"` — immediately after completion, score is exactly 100
- `test "health_score uses the most recent completion"` — create two completions at different times, score reflects the latest one
- `test "health_score is an integer"` — returns a whole number, not a float
- `test "SCORE_AT_ONE_PERIOD constant is defined"` — Task::SCORE_AT_ONE_PERIOD exists and equals 0.6
- `test "score at exactly one decay period matches calibration constant"` — complete a 1-day task, travel_to exactly 24 hours, score should be approximately 60 (100 * SCORE_AT_ONE_PERIOD)

### 1C: Score Color Helper (Continuous HSL Gradient)

**File: `test/helpers/score_color_helper_test.rb`**

- `test "score of 100 returns green hue (120)"` — score_color(100) returns `hsl(120, 70%, 45%)`
- `test "score of 0 returns red hue (0)"` — score_color(0) returns `hsl(0, 70%, 45%)`
- `test "score of 50 returns yellow hue (60)"` — score_color(50) returns `hsl(60, 70%, 45%)`
- `test "score of 75 returns yellow-green hue (90)"` — score_color(75) returns `hsl(90, 70%, 45%)`
- `test "score of 25 returns orange hue (30)"` — score_color(25) returns `hsl(30, 70%, 45%)`
- `test "nil score returns red"` — score_color(nil) returns `hsl(0, 70%, 45%)`
- `test "score is clamped to 0-100 range"` — score_color(150) returns same as score_color(100); score_color(-10) returns same as score_color(0)

### 1D: Room Scoring

**File: `test/models/room_test.rb`** (continued)

- `test "score is nil when room has no tasks"` — empty room returns nil
- `test "score is the average of task health scores"` — room with two tasks, one at 100 and one at 0, score is 50
- `test "score is 0 when all tasks have never been completed"` — room with three tasks, none completed, score is 0
- `test "score is 100 when all tasks were just completed"` — complete all tasks just now, score is 100
- `test "score rounds to nearest integer"` — three tasks with scores that average to a non-integer, result is rounded
- `test "room with one task uses that task's score directly"` — single task, room score equals task score
- `test "room with all tasks at 0 has score 0"` — no completions anywhere, room score is 0

### 1E: House Scoring (Room.house_score class method)

**File: `test/models/room_test.rb`** (continued)

- `test "house_score is nil when there are no rooms"` — no rooms, Room.house_score is nil
- `test "house_score is nil when all rooms have no tasks"` — rooms exist but have no tasks, Room.house_score is nil
- `test "house_score is the average of room scores"` — two rooms with scores 80 and 60 → Room.house_score is 70
- `test "house_score excludes rooms with nil scores (no tasks)"` — three rooms, one has no tasks (nil score), house score is calculated from the other two only
- `test "house_score rounds to nearest integer"` — average produces a non-integer, result is rounded
- `test "house_score with one room uses that room's score directly"` — single room, Room.house_score equals room score

---

## Phase 2: Room & Task Management

### 2A: Rooms CRUD

**File: `test/controllers/rooms_controller_test.rb`**

- `test "GET /rooms lists all rooms"` — response contains all room names
- `test "POST /rooms creates a room with valid params"` — Room.count increases by 1
- `test "PATCH /rooms/:id updates room attributes"` — changes name, verify it persists
- `test "DELETE /rooms/:id destroys the room and cascades"` — Room.count decreases, associated tasks and completions also deleted

### 2B: Tasks CRUD (Nested Under Rooms)

**File: `test/controllers/tasks_controller_test.rb`**

- `test "POST /rooms/:room_id/tasks creates a task"` — Task.count increases by 1, task belongs to the correct room
- `test "PATCH /rooms/:room_id/tasks/:id updates task attributes"` — changes name and decay_period, verify persistence
- `test "DELETE /rooms/:room_id/tasks/:id destroys the task and cascades"` — Task.count decreases, associated completions also deleted

---

## Phase 3: Mobile Quick-Log

### 3A: Home Controller (Room List)

**File: `test/controllers/home_controller_test.rb`**

- `test "GET / returns success"` — 200 response
- `test "GET / displays house score and rooms"` — response contains house score and room names with scores
- `test "GET / orders rooms by score ascending (worst first)"` — room with lowest score appears first
- `test "GET / with no rooms shows add room prompt"` — empty state message

### 3B: Room Task List (Mobile)

**File: `test/controllers/home_controller_test.rb`**

- `test "viewing a room's tasks shows tasks ordered by score ascending"` — most urgent task appears first, each has a done button
- `test "room with no tasks shows add tasks prompt"` — empty state

### 3C: Completions Controller

**File: `test/controllers/completions_controller_test.rb`**

- `test "POST /tasks/:task_id/completions creates a completion"` — Completion.count increases by 1
- `test "completion uses created_at as the completion time"` — the created completion's created_at is approximately Time.current
- `test "POST responds with turbo stream"` — response content type is turbo_stream
- `test "POST redirects to referrer for non-turbo requests"` — standard HTML request gets a redirect back
- `test "completing a task updates the task health score to 100"` — after completion, task.health_score is 100
- `test "POST with invalid task_id returns 404"` — task doesn't exist, get a 404 or redirect with error

---

## Phase 4: Kiosk Dashboard

### 4A: Dashboard Action (in HomeController)

**File: `test/controllers/home_controller_test.rb`** (continued — dashboard uses same controller)

- `test "GET /dashboard returns success"` — 200 response
- `test "GET /dashboard hides the nav bar"` — response does NOT contain nav links (conditional render)
- `test "GET /dashboard displays house score and room cards"` — response contains Room.house_score and room names

### 4B: Dashboard — Room Detail Interaction

**File: `test/controllers/home_controller_test.rb`** (continued)

- `test "clicking a room card loads room tasks via turbo frame"` — the room card links to a turbo frame with the room's tasks
- `test "room detail shows all tasks with scores and done buttons"` — the turbo frame response contains each task name, score, and a completion form/button

### 4C: Dashboard — Empty States

**File: `test/controllers/home_controller_test.rb`** (continued)

- `test "GET /dashboard with no rooms shows add room prompt"` — response contains "Add your first room" and a link to /rooms/new
- `test "GET /dashboard with a room that has no tasks shows placeholder"` — room card shows "--" for score

---

## Phase 5: Polish — Turbo Streams + Auto-Refresh

### 5A: Broadcast Configuration (Simplified)

**File: `test/models/completion_test.rb`** (continued)

- `test "Completion broadcasts_refreshes is configured"` — verify the model has `broadcasts_refreshes` declared

**Note:** Per DHH review, we don't need to test that Rails broadcasts work — if we declare `broadcasts_refreshes`, Rails will broadcast. One test to confirm the declaration exists is sufficient.

### 5B: Layout and Auto-Refresh

**File: `test/integration/turbo_streams_test.rb`**

- `test "dashboard view subscribes to house_scores stream"` — GET /dashboard, response contains turbo_stream_from tag for :house_scores
- `test "home view subscribes to house_scores stream"` — GET /, response contains turbo_stream_from tag for :house_scores
- `test "layout has turbo_refreshes_with morph"` — GET /, response contains turbo-refreshes-with meta tag with method="morph"
- `test "dashboard has meta refresh for decay updates"` — GET /dashboard, response contains `<meta http-equiv="refresh" content="3600">`
- `test "mobile does NOT have meta refresh"` — GET /, response does NOT contain `http-equiv="refresh"`

### 5C: System Tests for Turbo Stream Integration

**Note:** Uncomment the `system-test` job in `.github/workflows/ci.yml` when adding these tests.

**File: `test/system/turbo_streams_test.rb`**

- `test "completing a task updates scores on the same page"` — visit /, complete a task, verify the score changes without full page reload

**Deferred to v2:**
- `test "completing a task on mobile updates the kiosk view"` — open two browser sessions (mobile and kiosk), complete task on mobile, verify kiosk receives the update via Turbo Streams. Requires `Capybara.using_session` for multi-session testing which adds complexity.

**Note:** These system tests use Capybara and verify the critical path — that Turbo Streams actually work end-to-end, not just that the right HTML is rendered.

**Note:** Empty state tests are covered in Phase 4C (dashboard) and Phase 3A (mobile). Scoring edge cases are in Phase 1D (room) and 1E (house). No separate test files needed for edge cases.

---

## Test Execution Order

For TDD, implement in this order within each phase:

1. Write all model tests for the sub-phase (1A, 1B, etc.)
2. Run tests — confirm they fail (red)
3. Implement the minimum code to make tests pass (green)
4. Refactor if needed
5. Move to the next sub-phase

**Phase dependencies:**
- Phase 1 has no dependencies — start here
- Phase 2 depends on Phase 1 (models must work)
- Phase 3 depends on Phase 1 (models) and Phase 2 (rooms/tasks must exist)
- Phase 4 depends on Phase 3 (HomeController must exist with both actions)
- Phase 5 depends on Phases 2-4 (controllers must exist to test broadcasts)

**Test runner command:** `bin/rails test` (Minitest, Rails default)
