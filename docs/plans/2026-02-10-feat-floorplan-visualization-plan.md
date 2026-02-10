---
title: "feat: Floorplan Visualization"
type: feat
date: 2026-02-10
---

# feat: Floorplan Visualization

## Overview

Add a spatial floorplan view where users draw their house layout as rectangles on a pannable/zoomable canvas, with each room colored by its health score in real time. Desktop for editing, kiosk tablet for viewing. Lives at `/floorplan` alongside the existing dashboard and mobile views.

Rooms are HTML `<div>` elements absolutely positioned inside a container, styled with Tailwind and the existing `score_gradient` helper. A Stimulus controller handles drag, resize, pan/zoom, and debounced auto-save. Zero new JavaScript dependencies.

## Problem Statement / Motivation

The current dashboard shows rooms as a flat grid of colored cards — functional but abstract. Users can't see how their home *actually* looks. A spatial floorplan view lets you glance at a tablet on the wall and immediately see which *area* of your house needs attention, matching the mental model of walking through rooms.

## Proposed Solution

Extend the `Room` model with nullable spatial columns (`x`, `y`, `width`, `height` in a virtual 1000x1000 coordinate space). Add a `/floorplan` page that renders rooms as positioned, score-colored `<div>` rectangles on a pannable/zoomable canvas. Desktop users can drag rooms from a sidebar, draw new rooms, and resize/reposition them (debounced auto-save via a dedicated `PATCH /rooms/:id/position` endpoint). The kiosk tablet shows the same view read-only with tappable rooms that open the existing task modal. Turbo Streams provide live score updates.

## Technical Approach

### Data Model Changes

```mermaid
erDiagram
    Room ||--o{ Task : "has many"
    Task ||--o{ Completion : "has many"

    Room {
        bigint id PK
        string name "existing"
        integer x "nullable - virtual coord 0-1000"
        integer y "nullable - virtual coord 0-1000"
        integer width "nullable - virtual coord, positive"
        integer height "nullable - virtual coord, positive"
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

- **Virtual coordinate system (1000x1000):** Room positions are stored as integers in a fixed virtual grid. The view scales this to fit any screen size (desktop, kiosk tablet). A room at `(100, 200, 300, 150)` renders at 10%, 20%, 30%, 15% of the viewport regardless of screen resolution.
- **All spatial columns nullable:** Rooms without spatial data simply don't appear on the floorplan. Existing rooms, dashboard, and mobile views are completely unaffected.
- **All-or-nothing validation:** All four spatial fields must be present together or all nil. A room with `x` and `y` but no `width`/`height` is a broken state.
- **No zones in v1:** One canvas for everything. Users name rooms descriptively ("Downstairs Guest", "Master Bedroom") and position them spatially to represent floors/areas. Zone column intentionally deferred — will be added in a separate migration if needed.
- **No parent-child nesting:** All rooms are flat in the database. Visual overlap on the canvas (plant inside kitchen, car inside garage) is purely positional with no data relationship.
- **Model scopes:** `scope :placed` and `scope :unplaced` on Room for clean querying.

### Coordinate System and Scaling

```
Virtual Space (1000x1000)              Viewport (any size)
┌──────────────────────┐               ┌─────────────────┐
│  ┌─────┐             │   scale +     │ ┌───┐           │
│  │Room │             │   translate   │ │Rm │           │
│  │(100,│             │  ──────────>  │ └───┘           │
│  │200) │             │               │                 │
│  └─────┘             │               │                 │
│           ┌──────┐   │               │        ┌────┐   │
│           │Room  │   │               │        │Rm  │   │
│           └──────┘   │               │        └────┘   │
└──────────────────────┘               └─────────────────┘

Pan: translates the viewport offset
Zoom: scales the virtual-to-viewport ratio
```

### Saving Strategy: Debounced Auto-Save

Room positions are saved via a **dedicated member route** (`PATCH /rooms/:id/position`) that is separate from the existing `RoomsController#update`. This avoids overloading the CRUD update (which redirects) with the floorplan's silent auto-save (which returns `head :ok`).

When a room is moved or resized on the floorplan editor:

1. Stimulus controller captures the new position/dimensions in virtual coordinates
2. A 500ms debounce timer starts (reset on each new interaction)
3. After 500ms of inactivity, `PATCH /rooms/:id/position` fires with `{ room: { x: ..., y: ..., width: ..., height: ... } }`
4. On failure, show a brief error indicator
5. On success, no visible feedback needed (the position is already where the user put it)
6. On `turbo:before-visit`, flush any pending debounced save immediately to prevent data loss on navigation

### Implementation Phases

#### Phase 1: Database Migration + Model

Add spatial columns to Room with validations and scopes.

**Files to create/modify:**

- [x] `db/migrate/TIMESTAMP_add_spatial_data_to_rooms.rb` — add `x`, `y`, `width`, `height` (all nullable integers)

```ruby
class AddSpatialDataToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :x, :integer
    add_column :rooms, :y, :integer
    add_column :rooms, :width, :integer
    add_column :rooms, :height, :integer
  end
end
```

- [x] `app/models/room.rb` — add validations and scopes

```ruby
# Scopes
scope :placed, -> { where.not(x: nil) }
scope :unplaced, -> { where(x: nil) }

# Validations
validates :x, :y, numericality: { in: 0..1000 }, allow_nil: true
validates :width, :height, numericality: { greater_than: 0, less_than_or_equal_to: 1000 }, allow_nil: true
validate :spatial_data_complete_or_absent

private

def spatial_data_complete_or_absent
  fields = [x, y, width, height]
  unless fields.all?(&:present?) || fields.none?(&:present?)
    errors.add(:base, "spatial data must be fully present or fully absent")
  end
end
```

- [x] `app/helpers/score_color_helper.rb` — add `floorplan_gradient(room)` helper that returns gray for nil scores instead of red, eliminating inline ternaries in the view

```ruby
def floorplan_gradient(room)
  if room.score.nil?
    "background: hsl(0, 0%, 80%)"
  else
    score_gradient(room.score)
  end
end

def floorplan_color(room)
  if room.score.nil?
    "hsl(0, 0%, 70%)"
  else
    score_color(room.score)
  end
end
```

**Tests:**

- [x] `test/models/room_test.rb` — room with spatial data saves correctly; spatial fields are optional; partial spatial data (x without width) is invalid; negative width is invalid; x > 1000 is invalid; existing tests still pass
- [x] `test/helpers/score_color_helper_test.rb` — `floorplan_gradient` returns gray for nil-score rooms, gradient for scored rooms

#### Phase 2: Route + Controller + Position Endpoint + Basic View

Set up the floorplan page and the dedicated position-saving endpoint.

**Files to create/modify:**

- [x] `config/routes.rb` — add floorplan route and position member route

```ruby
get "floorplan", to: "home#floorplan"

resources :rooms, except: :show do
  member do
    patch :position
  end
  resources :tasks, except: %i[show]
end
```

- [x] `app/controllers/rooms_controller.rb` — add `position` action only (do NOT modify existing `room_params` or `update`)

```ruby
def position
  @room = Room.find(params[:id])
  if @room.update(position_params)
    head :ok
  else
    head :unprocessable_entity
  end
end

private

def position_params
  params.expect(room: [:x, :y, :width, :height])
end
```

- [x] `app/controllers/home_controller.rb` — add `floorplan` action with its own data loading (not reusing score-sorted loading from dashboard/mobile, since score order is meaningless on a spatial canvas)

```ruby
def floorplan
  rooms = Room.includes(tasks: :completions)
  @placed_rooms = rooms.placed
  @unplaced_rooms = rooms.unplaced.order(:name)
  @house_score = Room.house_score(rooms)
end
```

- [x] `app/views/home/floorplan.html.erb` — basic page with canvas container and room data

```erb
<%= turbo_stream_from :house_scores %>

<div id="floorplan-canvas"
     data-controller="floorplan"
     class="relative w-full h-screen overflow-hidden bg-gray-100">
  <% @placed_rooms.each do |room| %>
    <%= link_to room_tasks_path(room),
        data: { turbo_frame: "modal", room_id: room.id,
                x: room.x, y: room.y, width: room.width, height: room.height,
                name: room.name, score: room.score },
        class: "floorplan-room absolute rounded-lg shadow-md
               flex items-center justify-center text-white font-bold text-sm
               select-none overflow-hidden",
        style: "#{floorplan_gradient(room)}" do %>
      <span class="truncate px-1"><%= room.name %></span>
      <span class="text-xs opacity-75 ml-1"><%= room.score || '--' %></span>
    <% end %>
  <% end %>
</div>

<turbo-frame id="modal"></turbo-frame>
```

- [x] `app/views/shared/_navbar.html.erb` — add "Floorplan" link
- [x] `app/views/layouts/application.html.erb` — hide navbar on floorplan: `unless action_name.in?(%w[dashboard floorplan])`

**Tests:**

- [x] `test/controllers/home_controller_test.rb` — `GET /floorplan` returns 200; response includes floorplan container; placed rooms rendered; unplaced rooms listed
- [x] `test/controllers/rooms_controller_test.rb` — `PATCH /rooms/:id/position` with valid spatial params returns 200 and saves; invalid params return 422; existing `update` action is unaffected

#### Phase 3: Stimulus Controller — Core Interactions

Build the floorplan Stimulus controller with drag, resize, pan/zoom, and debounced auto-save.

**Files to create:**

- [x] `app/javascript/controllers/floorplan_controller.js` — (auto-registered via `eagerLoadControllersFrom`)

**Controller responsibilities:**

```
Stimulus Controller: floorplan_controller.js

Targets: none needed (queries DOM directly for room elements)
Values: none needed (reads data attributes from room elements)

Core features:
├── Pan: pointerdown on canvas background + pointermove translates viewport
├── Zoom: wheel event scales viewport (centered on cursor)
├── Drag rooms: pointerdown on room + pointermove updates position
├── Resize rooms: pointerdown on resize handle + pointermove updates dimensions
├── Debounced save: 500ms after last interaction, PATCH /rooms/:id/position
├── Virtual→screen coord conversion: positions in 1000x1000, rendered to viewport
└── turbo:before-visit: flush pending saves before navigation

Pointer event flow:
1. pointerdown → determine target (canvas background, room, or resize handle)
2. pointermove → update transform (pan), room position (drag), or room size (resize)
3. pointerup → end interaction, start debounce timer for save

Coordinate conversion (extract as pure functions for testability):
- virtualToScreen(vx, vy, scale, panX, panY) → { sx, sy }
- screenToVirtual(sx, sy, scale, panX, panY) → { vx, vy }
```

**Room rendering with edit controls (desktop only):**

Each placed room is rendered server-side as a positioned `<div>`. The Stimulus controller reads `data-x`, `data-y`, `data-width`, `data-height` to compute screen positions based on the current viewport scale. Resize handles are visible only at `lg:` breakpoint via Tailwind.

**Key implementation notes:**

- Rooms are real DOM elements — Turbo Stream morph updates their `style` attributes (colors) with zero custom code
- Use `pointer` events (not `mouse`) for unified mouse + touch handling
- CSS `transform: scale() translate()` on a wrapper div handles the viewport transform
- `touch-action: none` on the canvas to prevent browser scroll/zoom interference
- Distinguish drag-room vs. pan-canvas by checking `event.target`

**Tests:**

- [ ] JavaScript unit tests for `virtualToScreen()` and `screenToVirtual()` coordinate conversion functions
- [ ] System test: drag a room and verify position is saved (PATCH request made)

#### Phase 4: Sidebar + Draw New Room + Kiosk Integration

Build the room placement UI and kiosk viewing experience.

**Sidebar — Unplaced rooms:**

- [x] Sidebar built inline in `app/views/home/floorplan.html.erb` — left sidebar on desktop (`hidden lg:block`) listing unplaced rooms
- [x] Each unplaced room is draggable onto the canvas
- [x] When dropped, room gets default dimensions (150x100 in virtual coords) at the drop position
- [x] `PATCH /rooms/:id/position` fires to save

**"Draw New Room" tool (simplified per reviewer feedback):**

- [x] User clicks "+ New Room" button, entering draw mode (cursor changes)
- [x] User clicks and drags on canvas to define a rectangle
- [x] On mouseup, `POST /rooms` creates a room with a default name ("New Room") and the spatial data
- [x] New room appears on canvas immediately (page reloads via Turbo.visit)
- [ ] User can rename by clicking the room name, which opens a Turbo Frame inline edit (deferred to v2)

**Kiosk viewing mode:**

- [x] Edit controls (sidebar, resize handles, draw button) hidden below `lg:` breakpoint via Tailwind responsive classes
- [x] Rooms are tappable on kiosk — each room is a `link_to room_tasks_path(room)` with `data-turbo-frame="modal"` (same pattern as dashboard room cards)
- [x] `<turbo-frame id="modal">` at page bottom for task modal (reuse existing `tasks/index.html.erb` dialog)
- [x] `turbo_stream_from :house_scores` for live score updates
- [x] `<meta http-equiv="refresh" content="3600">` for hourly decay updates (present on all viewports; acceptable since debounced save fires within 500ms and desktop editing sessions are unlikely to span an hour without any interaction)
- [x] Pan/zoom available on kiosk (pinch to zoom on tablet)

**Edit mode vs view mode:**

- [x] Desktop (>= `lg` breakpoint): sidebar visible, resize handles visible, rooms draggable/resizable, draw button available
- [x] Tablet/kiosk (< `lg` breakpoint): sidebar hidden, resize handles hidden, rooms are view-only + tappable for task modal
- [x] No explicit toggle button needed — responsive CSS handles it

**Tests:**

- [x] Controller test: `POST /rooms` with name + spatial params creates a placed room
- [x] System test: placed room links to task modal via turbo frame
- [ ] System test: completing a task in the modal updates the room's color on the floorplan (covered by existing turbo streams system test)
- [x] System test: rooms with no tasks display gray (not red)

#### Phase 5: Testing & Polish

**Additional model tests** (`test/models/room_test.rb`):

- [x] `Room.placed` scope returns only rooms with spatial data
- [x] `Room.unplaced` scope returns only rooms without spatial data
- [x] `spatial_data_complete_or_absent` validation rejects partial spatial data

**Integration tests** (`test/integration/floorplan_turbo_test.rb`):

- [x] Floorplan page subscribes to `:house_scores` turbo stream
- [x] Score changes broadcast to floorplan (existing broadcast pattern)

**System tests** (`test/system/floorplan_test.rb`):

- [x] Visiting `/floorplan` shows placed rooms as colored elements
- [x] Unplaced rooms appear in the sidebar on desktop
- [x] Empty state shows helpful prompt when no rooms are placed

**Polish:**

- [x] Room rectangles show room name + score number
- [x] Small rooms truncate text gracefully (CSS `overflow-hidden truncate`)
- [x] Canvas has a subtle grid or dot background for spatial reference
- [x] Empty state: no placed rooms shows prompt ("Drag rooms from the sidebar to place them")
- [x] Room name display: show name prominently, score smaller below or beside it

## Acceptance Criteria

### Functional Requirements

- [ ] Visiting `/floorplan` on desktop shows a pannable/zoomable canvas with room rectangles
- [ ] Rooms on the canvas are colored by their health score using the existing gradient system
- [ ] Rooms with no tasks appear in neutral gray (not red)
- [ ] Desktop users can drag rooms from the sidebar onto the canvas to place them
- [ ] Desktop users can click and drag to draw a new room rectangle (created with default name, renamable inline)
- [ ] Desktop users can drag placed rooms to reposition them
- [ ] Desktop users can resize placed rooms via corner handles
- [ ] Room positions auto-save 500ms after the last interaction via `PATCH /rooms/:id/position`
- [ ] Desktop users can pan (drag background) and zoom (scroll wheel) the canvas
- [ ] Kiosk/tablet users see the floorplan read-only (no edit controls)
- [ ] Kiosk users can tap a room to open the task modal with completion buttons
- [ ] Completing a task updates the room's color on the floorplan in real time (Turbo Streams)
- [ ] Existing dashboard (`/dashboard`) and mobile (`/`) views are completely unaffected
- [ ] The floorplan page has an hourly meta refresh for time-based decay
- [ ] Pending saves flush on `turbo:before-visit` to prevent data loss

### Non-Functional Requirements

- [ ] Virtual 1000x1000 coordinate system scales to any screen size
- [ ] Works on kiosk tablet (touch pan/zoom, tappable rooms with 44px+ minimum targets)
- [ ] No new models — only columns added to existing Room
- [ ] No new JavaScript dependencies — HTML/CSS + Stimulus only
- [ ] Existing `RoomsController#update` is completely untouched

## Alternative Approaches Considered

1. **Canvas + Konva.js** — Built-in drag/resize/pan/zoom, but requires a custom Turbo Stream bridge (canvas is opaque to morph), rooms aren't DOM elements (breaks `data-turbo-frame="modal"` pattern for task modals), adds ~150KB dependency, worse accessibility. HTML/CSS approach was chosen because Turbo compatibility is free and the app currently has zero JS dependencies.

2. **SVG-based rendering** — SVG `<rect>` elements in the DOM. Good middle ground but SVG styling differs from HTML/CSS (no Tailwind), and text in SVG is finicky.

3. **Upload a floorplan image** — Let users upload a blueprint photo and overlay clickable zones. Great for accuracy but much more complex. Deferred to v2.

4. **Grid-based painting** — Paint rooms on a grid like pixel art. Fun but tedious for real floorplans and doesn't support arbitrary room sizes well.

## Dependencies & Risks

| Risk | Mitigation |
|------|-----------|
| Pan/zoom via CSS transform may feel less smooth than native canvas | Test on kiosk tablet early; CSS transforms perform well for 20-30 elements |
| Debounced auto-save could lose data on page nav | Flush pending saves on `turbo:before-visit`; positions are low-stakes data |
| Overlapping rooms on kiosk may have confusing tap targets | Allow overlap; topmost room receives tap. Users can rearrange to avoid overlap |
| Turbo morph during active drag could disrupt editing | Unlikely (morph triggered by completions on other devices); debounced save persists position before morph |
| Stimulus controller could grow large (drag, resize, pan, zoom, save) | Keep it focused on DOM events → server actions; extract coordinate conversion as pure functions |
| Hourly meta refresh on desktop could lose unsaved drag positions | Debounce is 500ms, so positions are saved well before the 1-hour refresh |

## Open Questions (Deferred to v2+)

- Zones/floors for very large houses (add `zone` string column when needed)
- Undo/redo for layout changes
- Snap-to-grid or snap-to-edges alignment
- Background image (uploaded blueprint) overlay
- Auto-cycling zones on kiosk
- Keyboard shortcuts for room manipulation (arrow keys to nudge, Delete to unplace)

## References

### Brainstorm

- `docs/brainstorms/2026-02-10-floorplan-visualization-brainstorm.md`

### Internal References

- Room model: `app/models/room.rb`
- Score color helper: `app/helpers/score_color_helper.rb`
- Dashboard view pattern: `app/views/home/dashboard.html.erb`
- Room card partial: `app/views/home/_room_card.html.erb`
- Dialog controller (Stimulus pattern): `app/javascript/controllers/dialog_controller.js`
- Task modal (reusable): `app/views/tasks/index.html.erb`
- Importmap config: `config/importmap.rb`
- Existing routes: `config/routes.rb`
- Rooms controller: `app/controllers/rooms_controller.rb`
- Home controller: `app/controllers/home_controller.rb`

### External References

- CSS transform for pan/zoom: `transform: scale() translate()`
- Stimulus values/targets: https://stimulus.hotwired.dev/reference/values
- Pointer Events API: https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events
