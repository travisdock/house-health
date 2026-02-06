# Review Feedback — House Health Tracker Plans

Consolidated feedback from DHH Rails Reviewer, Simplicity Reviewer, and Architecture Strategist.

---

## Must Fix

These are bugs or clear improvements with no downside.

- [x] **1. Fix integer division bug in `room_score`** ✅
  - Current: `tasks.sum(&:health_score) / tasks.size` (integer division)
  - Fix: `(tasks.sum(&:health_score).to_f / tasks.size).round`
  - Two tasks at 99 and 100 currently produce 99, not 100

- [x] **2. Extract decay calibration constant** ✅
  - Current: Magic number `0.5108` buried in formula
  - Fix: `SCORE_AT_ONE_PERIOD = 0.6` then derive `k = -Math.log(SCORE_AT_ONE_PERIOD) / decay_period_hours`
  - Makes the tuning knob explicit and self-documenting

- [x] **3. Use resourceful routing for completions** ✅
  - Current: `post "/tasks/:task_id/completions", to: "completions#create"`
  - Fix: `resources :tasks, only: [] do; resources :completions, only: [:create]; end`
  - Standard Rails routing instead of hand-drawn route

- [x] **4. Consolidate redundant tests** ✅
  - Deleted `test/models/scoring_edge_cases_test.rb` — moved tests to room_test.rb and house_test.rb
  - Deleted `test/integration/empty_states_test.rb` — already covered in controller tests
  - Removed duplicate auto-creation test from home_controller (kept in dashboard_controller)
  - Removed color helper tests from model tests (helper has its own dedicated tests)

---

## Consensus Recommendations

All three reviewers agree on these. Low risk to adopt.

- [x] **5. Drop the `House` model** ✅
  - Always exactly one, auto-created, no CRUD UI
  - Replace with `Room.house_score` class method
  - Eliminates: model, migration, `house_id` FK on Room, `before_action` auto-creation, 10+ tests

- [x] **6. Use morph-based broadcasts instead of targeted `replace`** ✅
  - Problem: Kiosk and mobile have different DOM structures; targeted `replace` to `room_card_3` does nothing on mobile
  - Fix: Use `broadcasts_refreshes` on Completion model + `turbo_refreshes_with method: :morph` in layouts
  - Simpler code, works across both views, idiomatic Rails 8

- [x] **7. ~~Rename `RefreshScoresJob` to `BroadcastScoreRefreshJob`~~ — Removed job entirely** ✅
  - Replaced with `<meta http-equiv="refresh" content="60">` on kiosk layout
  - No Solid Queue infrastructure needed at all
  - Simpler: each client refreshes itself, no server-side job coordination

---

## Debatable Simplifications

Reviewers suggested these, but they involve tradeoffs. Decide before implementation.

- [x] **8. Replace `Completion` model with `last_completed_at` column on Task** — **Rejected** ✅
  - Decision: Keep the Completion model
  - Reason: Historical data is valuable for v2 trends; migrating from a column to a model later is harder than keeping it now

- [x] **9. Move debounce logic from controller to model** — **Removed entirely** ✅
  - Decision: Rely on Turbo's `data-turbo-submits-with` to disable button during submission
  - No server-side debounce needed; can add later if it becomes a problem
  - Also removed redundant `completed_at` column — just use `created_at`

- [x] **10. ~~Replace `PresetLibrary` model + YAML with a constant hash~~ — Removed presets entirely** ✅
  - Decision: No presets at all — users add their own rooms and tasks from scratch
  - Removed: `PresetLibrary` model, `presets.yml`, `room_type` column
  - Simpler onboarding: just "Add Room" → enter name and weight → "Add Task"

---

## Nice to Have

Lower priority improvements. Can defer to later.

- [ ] **11. Add system tests for Turbo Stream flows**
  - No Capybara/headless tests currently planned
  - Should test: complete task on mobile → kiosk updates, morph refresh works
  - Decision: Add to v1 / Defer to v2

- [ ] **12. Add query-count test to prevent N+1**
  - Scoring rollup calls `completions.maximum(:completed_at)` per task
  - Should assert query count doesn't grow with task count
  - Related: Consider denormalizing `last_completed_at` or eager loading
  - Decision: Add to v1 / Defer to v2

- [x] **13. Replace hamburger menu with simple top nav** ✅
  - Three links: Home, Dashboard, Rooms
  - All visible in a row — no hamburger menu needed

- [x] **14. Remove `position` columns (deferred to v2)** ✅
  - Removed `position` from both Room and Task
  - Use alphabetical ordering for v1; add position columns when drag-to-reorder is needed

---

## Rejected Suggestions

Reviewers suggested these, but I recommend keeping the current approach.

- **Room weights** — Simplicity reviewer suggested removing as YAGNI, but weighted room scoring was explicitly requested during brainstorm. Keep it.

- **Dark mode line item** — Simplicity reviewer said to remove from plan since it's optional. I'd keep it as a documented nice-to-have; removing it loses the idea entirely.

---

## How to Proceed

For each item above, mark your decision:
- **Accept** — I'll update the plans to incorporate this
- **Reject** — Keep the current approach
- **Discuss** — You have questions or want to talk through tradeoffs

Once decisions are made, I'll update both the implementation plan and testing plan accordingly.
