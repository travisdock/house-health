# Review Feedback Round 2 — House Health Tracker

Consolidated feedback from DHH Rails Reviewer, Simplicity Reviewer, and Architecture Strategist.

---

## DHH Rails Reviewer

### DHH-1: Stop calling it "Scoring Engine"

**Current:** The architecture diagram calls it "Scoring Engine (Ruby)"

**Issue:** It's just three model methods (`Task#health_score`, `Room#score`, `Room.house_score`). Calling it an "engine" implies it should be extracted into a service object, module, or gem.

**Suggested fix:** Just call them what they are — model methods. Remove "Scoring Engine" terminology from the plan.

**Decision:** [x] Accept

---

### DHH-2: Remove `Task#color` — keep presentation in helpers

**Current:** Plan includes `Task#color — delegates to ScoreColorHelper.score_color(health_score)`

**Issue:** Models should not know about HSL color values. This is presentation logic that belongs in the view layer.

**Suggested fix:** Remove `Task#color`. Call the helper directly from views:
```erb
<%= score_color(task.health_score) %>
```

**Decision:** [x] Accept

---

### DHH-3: Merge `DashboardController` into `HomeController`

**Current:** Two separate controllers:
- `HomeController#index` for `/`
- `DashboardController#show` for `/dashboard`

**Issue:** They're two views of the same data. One controller, two actions.

**Suggested fix:**
```ruby
# routes.rb
root "home#index"
get "dashboard", to: "home#dashboard"

# home_controller.rb
def index
  # mobile view
end

def dashboard
  # kiosk view
end
```

**Decision:** [x] Accept

---

### DHH-4: Use one layout with conditional nav

**Current:** Two separate layout files:
- `app/views/layouts/application.html.erb`
- `app/views/layouts/dashboard.html.erb`

**Issue:** A whole separate layout file just to remove the nav bar is overkill.

**Suggested fix:** One layout with a conditional:
```erb
<%# app/views/layouts/application.html.erb %>
<%= render "shared/navbar" unless action_name == "dashboard" %>
```

Or the dashboard action can use `render layout: false` and include the full HTML in its view.

**Decision:** [x] Accept

---

### DHH-5: Phase structure is waterfall thinking

**Current:** Five phases with dependencies documented.

**Issue:** This is a weekend project, not a quarterly roadmap. The phase structure adds planning overhead without value.

**Suggested fix:** Simplify to:
1. Generate the app and models
2. Add the views and controllers
3. Add Turbo Streams
4. Polish

**Counter-argument:** The phases help with TDD organization — writing tests before implementation for each sub-phase.

**Decision:** [x] Reject — keeping phases for TDD organization

---

### DHH-6: Broadcast tests are testing Rails, not your app

**Current:** Testing plan includes 8 tests for broadcasts:
- `test "Completion broadcasts_refreshes is configured"`
- `test "creating a completion broadcasts a refresh to house_scores stream"`
- `test "creating a room broadcasts a refresh"`
- etc.

**Issue:** If you write `broadcasts_refreshes` in your model, Rails will broadcast refreshes. You're testing that Rails works, not that your app works.

**Suggested fix:** Remove most broadcast tests. At most, one test to confirm the declaration exists:
```ruby
test "Completion broadcasts refreshes" do
  assert Completion.respond_to?(:broadcasts_refreshes)
end
```

**Decision:** [x] Accept

---

### DHH-7: Missing system tests for Turbo Streams

**Current:** No Capybara/system tests planned. Controller tests check for turbo_stream content types but don't verify the full flow.

**Issue:** The actual critical path — completing a task on mobile and seeing the kiosk update — is untested.

**Suggested fix:** Add system tests that:
1. Complete a task on mobile
2. Verify the kiosk updates in real-time

**Decision:** [x] Accept

---

### DHH-8: `Room.house_score` should use eager loading

**Current:**
```ruby
def self.house_score
  scored_rooms = Room.all.select { |r| r.score.present? }
  # ...
end
```

**Issue:** `Room.all.select` loads all rooms into memory. Add `includes(:tasks)` to avoid N+1 queries.

**Suggested fix:**
```ruby
def self.house_score
  scored_rooms = Room.includes(:tasks).select { |r| r.score.present? }
  # ...
end
```

**Note:** Since `score` is computed (not stored), you can't filter in SQL. But eager loading prevents N+1.

**Decision:** [x] Accept

---

## Simplicity Reviewer

### SIMPLE-1: Remove room weights entirely

**Current:** Rooms have a `weight` column (1-10) used for weighted house score calculation.

**Issue:** Adds complexity for marginal value in a single-user app:
- UI for weight slider
- Validation logic (1-10 range)
- Weighted average calculation
- 8+ tests just for weights

**Suggested fix:** Remove weights. Use simple averages. If the user cares more about certain rooms, they can add more tasks to them.

**Counter-argument:** Weighted room scoring was explicitly requested during brainstorm.

**Decision:** [x] Accept — easy to add later if needed

---

### SIMPLE-2: Replace Completion model with `Task.last_completed_at`

**Current:** Three models: Room -> Task -> Completion. Only the most recent completion matters for scoring.

**Issue:** Keeping all historical completions "for future trend features (v2)" is YAGNI. Eliminates:
- Entire Completion model
- Migration
- Associations
- Cascade deletes
- Broadcast logic
- ~10 tests

**Suggested fix:** Add `last_completed_at` datetime column to Task. Update it on completion. Delete Completion model.

**Counter-argument:** User explicitly rejected this in round 1 — wants historical data for v2 trends.

**Decision:** [x] Reject — keeping Completion model for historical data

---

### SIMPLE-3: Remove Turbo Streams broadcasting entirely

**Current:** Solid Cable + `broadcasts_refreshes` + `turbo_stream_from` for real-time updates.

**Issue:** For a single-user app, who is watching the kiosk while simultaneously using their phone? The hourly meta-refresh already handles decay updates. The phone user sees their own updates immediately because they just clicked.

**Suggested fix:** Remove Action Cable/Solid Cable/Turbo Streams broadcasts. Use standard Turbo navigation (full page morphing on form submit).

**Counter-argument:** The kiosk use case assumes the display is always on. If someone else in the household completes a task, you'd want to see it update. Also, Turbo Streams are already built into Rails 8 — removing them might be more work than keeping them.

**Decision:** [x] Reject — keeping Turbo Streams for real-time kiosk updates

---

### SIMPLE-4: Remove toast notifications

**Current:** Plan includes toast feedback after completing a task via Turbo Stream append.

**Issue:** The score changing from red to green IS the feedback. A toast is unnecessary UI polish.

**Suggested fix:** Remove toast system. Let the score update be the feedback.

**Decision:** [x] Accept — replacing with CSS animation on score change

---

### SIMPLE-5: Inline `SCORE_AT_ONE_PERIOD` constant

**Current:** `SCORE_AT_ONE_PERIOD = 0.6` as a class constant.

**Issue:** Making it a named constant suggests future tunability that isn't needed. If you ever change it, you'll be rewriting the formula anyway.

**Suggested fix:** Inline the value directly in the formula.

**Counter-argument:** The constant was added in round 1 specifically to make the "tuning knob explicit and self-documenting."

**Decision:** [x] Reject — keeping constant for self-documentation

---

### SIMPLE-6: Remove "most urgent task" display on room cards

**Current:** Dashboard room cards show "most urgent task name (lowest health_score)."

**Issue:** Visual clutter. The color already communicates urgency. The user taps to see tasks.

**Suggested fix:** Just show room name and score on cards.

**Decision:** [x] Accept — color communicates urgency, tap to see tasks

---

### SIMPLE-7: Remove decay period helper buttons

**Current:** Task form includes helper buttons: "Daily", "Weekly", etc. for setting `decay_period_days`.

**Issue:** UI polish for an infrequent action. Just use a number input.

**Suggested fix:** Remove helper buttons. Plain number input only.

**Decision:** [x] Accept — plain number input is sufficient

---

### SIMPLE-8: Consolidate redundant controller tests

**Current:** Tests like:
- `test "GET / shows color indicators for rooms"` — verifies HSL styles in response
- `test "POST /rooms with invalid params re-renders form with errors"`

**Issue:** Some tests are testing presentation details covered by helper tests, or testing standard Rails scaffold behavior.

**Suggested fix:** Keep only: create works, destroy cascades, update works. Remove tests that verify Rails behavior.

**Decision:** [x] Accept — remove tests that verify Rails scaffold behavior

---

## Architecture Strategist

### ARCH-1: Add eager loading to scoring queries (or query-count tests)

**Current:** Scoring rollup loads all rooms, then all tasks per room, then queries `completions.maximum(:created_at)` per task.

**Issue:** N+1 query pattern. Acceptable for ~10 rooms and ~50 tasks, but should be monitored.

**Suggested fix:** Either:
1. Add `includes(tasks: :completions)` in controllers
2. Add a query-count test to catch regression

**Decision:** [x] Accept — adding `includes(tasks: :completions)` in controllers

---

### ARCH-2: Document deployment security model

**Current:** Plan states "single-user, no authentication" but doesn't specify deployment target.

**Issue:** Safe for local/home network. Risky if deployed to public URL (Fly.io, Render, Heroku).

**Suggested fix:** Add a section specifying the expected deployment model. If public deployment is possible, recommend HTTP Basic Auth or IP allowlisting.

**Decision:** [x] Accept — documenting Digital Ocean + Tailscale deployment

---

### ARCH-3: Add system test for Turbo Stream broadcast flow

**Current:** No system/integration tests for the full broadcast flow.

**Issue:** The critical path (complete task → kiosk updates) is only tested in parts, not end-to-end.

**Suggested fix:** Add at least one system test:
```ruby
test "completing a task updates the kiosk in real-time" do
  # Complete task via mobile interface
  # Assert kiosk view receives update
end
```

**Note:** Same as DHH-7.

**Decision:** [x] Accept — adding system tests to Phase 5 (single-session only for v1; multi-session deferred to v2)

---

### ARCH-4: Consider Completion retention policy

**Current:** Every task completion creates a new record. ~7,300 records/year for typical usage.

**Issue:** Not an immediate concern (SQLite handles millions of rows), but worth noting for long-term.

**Suggested fix:** For v2, consider a retention policy or archival strategy.

**Decision:** [x] Reject — not a concern for v1

---

### ARCH-5: Time-dependent tests need careful `travel_to` usage

**Current:** Testing plan uses `travel_to` for decay tests.

**Issue:** Real-world time drift could cause test flakiness.

**Suggested fix:** Ensure all time-dependent tests:
1. Freeze time at the start
2. Use relative/approximate assertions (e.g., "approximately 60" rather than "exactly 60")

**Decision:** [x] Accept — adding note to testing plan

---

## Summary by Priority

### Likely Accept (low risk, clear improvement)
- DHH-1: Stop calling it "Scoring Engine"
- DHH-2: Remove `Task#color`
- DHH-8: Add eager loading
- ARCH-5: Careful `travel_to` usage

### Worth Discussing (tradeoffs involved)
- DHH-3: Merge controllers
- DHH-4: One layout
- DHH-6: Reduce broadcast tests
- DHH-7/ARCH-3: Add system tests
- SIMPLE-4: Remove toasts
- SIMPLE-6: Remove "most urgent task"
- SIMPLE-7: Remove helper buttons
- ARCH-2: Document deployment model

### Previously Rejected (user decision)
- SIMPLE-1: Remove room weights — explicitly requested feature
- SIMPLE-2: Remove Completion model — user wants historical data
- SIMPLE-5: Inline constant — added for self-documentation

### Contentious (reviewers disagree)
- SIMPLE-3: Remove Turbo Streams — DHH approves them, Simplicity says overkill
