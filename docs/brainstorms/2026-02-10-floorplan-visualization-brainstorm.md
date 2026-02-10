# Floorplan Visualization Brainstorm

**Date:** 2026-02-10
**Status:** Ready for prototyping

## What We're Building

A spatial floorplan view where users can draw their house layout as rectangles on a canvas, then see each room colored by its health score in real time. This replaces the abstract grid of room cards with a view that mirrors the user's actual home layout.

**Key capabilities:**
- **Draw/edit on desktop:** Click and drag to place rectangular rooms, resize and reposition them
- **View on kiosk (primary):** See the floorplan with live-updating score colors on the tablet dashboard
- **Mobile view:** Nice-to-have, not critical for v1
- **Separate page:** Lives at its own route (e.g., `/floorplan`), not replacing the existing dashboard or mobile views

## Core Concepts

### Flat entities, visual nesting only

All entities (rooms, plants, car, etc.) are flat in the database — each has its own independent tasks and score. There is **no score cascading** (a plant's health does not affect its room's score).

However, entities can be **visually nested** on the canvas. A plant rectangle can sit inside a kitchen rectangle, a car inside a garage — this is purely positional (z-ordering + coordinates), with no database parent-child relationship.

**Rationale:** Keeps the scoring model simple and avoidable coupling (a neglected plant shouldn't tank a spotless kitchen's score). Nesting/cascading can be added later via a `parent_id` migration if desired.

### Zones (future expansion)

Rooms already exist in the database. To support multiple floors, yards, and vehicles, we'll add:
- A `zone` label on each room (e.g., "Main Floor", "Upstairs", "Backyard", "Garage")
- The floorplan view lets you switch between zones (tabs or dropdown)
- Each zone has its own canvas with positioned rectangles

This is a lightweight extension of the existing Room model — no new models needed.

### Spatial data on rooms

Each room gains positional fields for its rectangle on the floorplan:
- `x`, `y` (position on canvas)
- `width`, `height` (rectangle dimensions)
- `zone` (which floorplan canvas it belongs to)

Rooms without spatial data simply don't appear on the floorplan (backward compatible).

## Approach: Prototype Both, Then Decide

Two approaches will be prototyped early so we can compare UX:

### Option A: HTML/CSS + Stimulus (no dependencies)

Rooms are `<div>` elements absolutely positioned inside a container div. Drag-to-move and resize handles built as a Stimulus controller.

- **Pros:** Zero dependencies, Turbo Streams work for free (rooms are DOM elements that can be morphed), existing `score_gradient` helper applies directly, accessible, Tailwind-styleable
- **Cons:** Building drag/resize from scratch takes effort, no built-in snap-to-grid

### Option B: Canvas with drawing library (e.g., Fabric.js or Konva.js)

Rooms are shapes on an HTML `<canvas>` element, managed by a JS library.

- **Pros:** Smoother drawing UX out of the box, built-in hit detection/layering/snapping, more "app-like" feel
- **Cons:** Canvas doesn't work with Turbo Streams (need manual redraws), requires vendoring a JS library via importmap, worse accessibility

### Decision point

After seeing both prototypes, choose one approach before building the full feature. Key evaluation criteria:
1. Does the drag/resize UX feel good enough with pure HTML/CSS?
2. Is the Turbo Stream compatibility of Option A worth the rougher drawing UX?
3. How much effort is the JS library integration for Option B?

## Key Decisions Made

1. **Simple rectangles** for room shapes (no freeform polygons)
2. **Flat scores, visual nesting only** — no cascading parent-child scores
3. **Separate page** — floorplan is a new route, not replacing existing views
4. **Desktop editing, kiosk viewing** — draw/edit only on desktop, view on tablet
5. **Zones for multi-floor/area support** — lightweight label on rooms, switchable in UI
6. **Prototype both approaches** before committing to HTML/CSS vs. Canvas

## Open Questions

- What should the floorplan route be? (`/floorplan`, `/map`, `/layout`?)
- Should the floorplan editor have an explicit "edit mode" toggle, or always be editable on desktop?
- How should rooms without spatial data (not yet placed on floorplan) be handled in the UI? Show a sidebar list of unplaced rooms?
- Should zone management (create/rename/delete zones) be part of v1 or can zones be hardcoded initially?
- Canvas dimensions: fixed size or responsive/zoomable?

## Out of Scope for v1

- Freeform polygon room shapes
- Score cascading / parent-child relationships
- Image upload (floorplan blueprint as background)
- Mobile editing
- Snap-to-grid / alignment guides (nice-to-have, not critical)
- Undo/redo for drawing actions
