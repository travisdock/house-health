import { Controller } from "@hotwired/stimulus"

const VIRTUAL_SIZE = 1000
const DEBOUNCE_MS = 500
const MIN_ROOM_SIZE = 30
const ZOOM_SENSITIVITY = 0.001
const MIN_SCALE = 0.2
const MAX_SCALE = 5
const ZOOM_FACTOR = 1.1

function screenToVirtual(sx, sy, scale, panX, panY) {
  return { vx: (sx - panX) / scale, vy: (sy - panY) / scale }
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content
}

function authenticatedFetch(url, options = {}) {
  return fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "X-CSRF-Token": csrfToken(),
      ...options.headers
    }
  })
}

export default class extends Controller {
  static targets = ["viewport", "canvas"]
  static values = { editable: { type: Boolean, default: false } }

  initialize() {
    this.scale = 1
    this.panX = 0
    this.panY = 0
  }

  connect() {
    this.interaction = null
    this.saveTimers = {}
    this.saveAbortControllers = {}
    this.drawMode = false

    this.fitToViewport()
    if (this.editableValue) this.addResizeHandles()

    // Store bound references so they can be removed in disconnect()
    this._onPointerDown = this.onPointerDown.bind(this)
    this._onPointerMove = this.onPointerMove.bind(this)
    this._onPointerUp = this.onPointerUp.bind(this)
    this._onWheel = this.onWheel.bind(this)
    this._onDragStart = e => e.preventDefault()

    this.canvasTarget.addEventListener("pointerdown", this._onPointerDown)
    this.canvasTarget.addEventListener("pointermove", this._onPointerMove)
    this.canvasTarget.addEventListener("pointerup", this._onPointerUp)
    this.canvasTarget.addEventListener("wheel", this._onWheel, { passive: false })
    this.canvasTarget.addEventListener("pointercancel", this._onPointerUp)

    // Prevent native browser drag on room links
    this.viewportTarget.addEventListener("dragstart", this._onDragStart)

    // Flush pending saves before navigation
    this._boundFlush = this.flushSaves.bind(this)
    document.addEventListener("turbo:before-visit", this._boundFlush)

    // Re-apply viewport transform after Turbo morph
    this._boundOnRender = this.onTurboRender.bind(this)
    document.addEventListener("turbo:render", this._boundOnRender)

    // Prevent browser zoom/scroll on canvas
    this.canvasTarget.style.touchAction = "none"
  }

  disconnect() {
    this.flushSaves()

    this.canvasTarget.removeEventListener("pointerdown", this._onPointerDown)
    this.canvasTarget.removeEventListener("pointermove", this._onPointerMove)
    this.canvasTarget.removeEventListener("pointerup", this._onPointerUp)
    this.canvasTarget.removeEventListener("wheel", this._onWheel)
    this.canvasTarget.removeEventListener("pointercancel", this._onPointerUp)
    this.viewportTarget.removeEventListener("dragstart", this._onDragStart)

    document.removeEventListener("turbo:before-visit", this._boundFlush)
    document.removeEventListener("turbo:render", this._boundOnRender)
  }

  onTurboRender() {
    this.applyTransform()
    if (this.editableValue) this.addResizeHandles()
  }

  // --- Layout ---

  fitToViewport() {
    const rect = this.canvasTarget.getBoundingClientRect()
    const scaleX = rect.width / VIRTUAL_SIZE
    const scaleY = rect.height / VIRTUAL_SIZE
    this.scale = Math.min(scaleX, scaleY) * 0.9
    this.panX = (rect.width - VIRTUAL_SIZE * this.scale) / 2
    this.panY = (rect.height - VIRTUAL_SIZE * this.scale) / 2
    this.applyTransform()
  }

  applyTransform() {
    if (!this.hasViewportTarget) return
    this.viewportTarget.style.transform =
      `translate(${this.panX}px, ${this.panY}px) scale(${this.scale})`
  }

  addResizeHandles() {
    this.roomElements().forEach(el => {
      if (el.querySelector(".resize-handle")) return
      const handle = document.createElement("div")
      handle.className = "resize-handle absolute bottom-0 right-0 w-4 h-4 cursor-se-resize hidden lg:block"
      handle.style.background = "rgba(255,255,255,0.5)"
      handle.style.borderRadius = "2px"
      el.appendChild(handle)
    })
  }

  roomElements() {
    return this.canvasTarget.querySelectorAll(".floorplan-room[data-room-id]")
  }

  // --- Pointer Events ---

  onPointerDown(event) {
    // Let non-room links (e.g. Edit button) pass through to the browser
    if (event.target.closest("a:not(.floorplan-room)")) return

    const resizeHandle = event.target.closest(".resize-handle")
    const roomEl = event.target.closest(".floorplan-room[data-room-id]")

    if (this.drawMode && !roomEl) {
      this.startDraw(event)
      return
    }

    if (resizeHandle && roomEl) {
      event.preventDefault()
      event.stopPropagation()
      this.startResize(event, roomEl)
    } else if (roomEl && this.editableValue) {
      event.preventDefault()
      event.stopPropagation()
      this.startDrag(event, roomEl)
    } else if (!roomEl) {
      this.startPan(event)
    }
  }

  onPointerMove(event) {
    if (!this.interaction) return
    event.preventDefault()

    const { type } = this.interaction
    if (type === "pan") this.movePan(event)
    else if (type === "drag") this.moveDrag(event)
    else if (type === "resize") this.moveResize(event)
    else if (type === "draw") this.moveDraw(event)
  }

  onPointerUp(_event) {
    if (!this.interaction) return

    const { type } = this.interaction
    if (type === "drag") this.endDrag()
    else if (type === "resize") this.endResize()
    else if (type === "draw") this.endDraw()

    this.interaction = null
  }

  // --- Pan ---

  startPan(event) {
    this.interaction = {
      type: "pan",
      startX: event.clientX,
      startY: event.clientY,
      startPanX: this.panX,
      startPanY: this.panY
    }
    this.canvasTarget.setPointerCapture(event.pointerId)
  }

  movePan(event) {
    const dx = event.clientX - this.interaction.startX
    const dy = event.clientY - this.interaction.startY
    this.panX = this.interaction.startPanX + dx
    this.panY = this.interaction.startPanY + dy
    this.applyTransform()
  }

  // --- Zoom ---

  onWheel(event) {
    event.preventDefault()

    const rect = this.canvasTarget.getBoundingClientRect()
    const mouseX = event.clientX - rect.left
    const mouseY = event.clientY - rect.top

    const oldScale = this.scale
    const delta = -event.deltaY * ZOOM_SENSITIVITY
    this.scale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, this.scale * (1 + delta)))

    // Zoom centered on cursor
    this.panX = mouseX - (mouseX - this.panX) * (this.scale / oldScale)
    this.panY = mouseY - (mouseY - this.panY) * (this.scale / oldScale)

    this.applyTransform()
  }

  // --- Drag Room ---

  startDrag(event, roomEl) {
    roomEl.dataset.dragging = "true"
    roomEl.addEventListener("click", this.preventClick, { once: true, capture: true })

    this.interaction = {
      type: "drag",
      roomEl,
      startX: event.clientX,
      startY: event.clientY,
      startVX: parseFloat(roomEl.dataset.x),
      startVY: parseFloat(roomEl.dataset.y),
      moved: false
    }
    this.canvasTarget.setPointerCapture(event.pointerId)
  }

  moveDrag(event) {
    const { roomEl, startX, startY, startVX, startVY } = this.interaction
    const dx = (event.clientX - startX) / this.scale
    const dy = (event.clientY - startY) / this.scale

    if (Math.abs(dx) > 2 || Math.abs(dy) > 2) {
      this.interaction.moved = true
    }

    const newVX = Math.max(0, Math.min(VIRTUAL_SIZE, Math.round(startVX + dx)))
    const newVY = Math.max(0, Math.min(VIRTUAL_SIZE, Math.round(startVY + dy)))

    roomEl.style.left = `${newVX}px`
    roomEl.style.top = `${newVY}px`
    roomEl.dataset.x = newVX
    roomEl.dataset.y = newVY
  }

  endDrag() {
    const { roomEl, moved } = this.interaction
    delete roomEl.dataset.dragging

    if (!moved) {
      roomEl.removeEventListener("click", this.preventClick, { capture: true })
    }

    if (moved) {
      this.scheduleSave(roomEl)
    }
  }

  preventClick(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  // --- Resize Room ---

  startResize(event, roomEl) {
    this.interaction = {
      type: "resize",
      roomEl,
      startX: event.clientX,
      startY: event.clientY,
      startVW: parseFloat(roomEl.dataset.width),
      startVH: parseFloat(roomEl.dataset.height)
    }
    this.canvasTarget.setPointerCapture(event.pointerId)
  }

  moveResize(event) {
    const { roomEl, startX, startY, startVW, startVH } = this.interaction
    const dx = (event.clientX - startX) / this.scale
    const dy = (event.clientY - startY) / this.scale

    const newVW = Math.max(MIN_ROOM_SIZE, Math.round(startVW + dx))
    const newVH = Math.max(MIN_ROOM_SIZE, Math.round(startVH + dy))

    roomEl.style.width = `${newVW}px`
    roomEl.style.height = `${newVH}px`
    roomEl.dataset.width = newVW
    roomEl.dataset.height = newVH
  }

  endResize() {
    this.scheduleSave(this.interaction.roomEl)
  }

  // --- Draw New Room ---

  startDrawMode() {
    this.drawMode = true
    this.canvasTarget.style.cursor = "crosshair"
  }

  startDraw(event) {
    const rect = this.canvasTarget.getBoundingClientRect()
    const sx = event.clientX - rect.left
    const sy = event.clientY - rect.top
    const { vx, vy } = screenToVirtual(sx, sy, this.scale, this.panX, this.panY)

    const tempRoom = document.createElement("div")
    tempRoom.className = "absolute rounded-lg border-2 border-dashed border-blue-500 bg-blue-200/30"
    tempRoom.style.left = `${Math.round(vx)}px`
    tempRoom.style.top = `${Math.round(vy)}px`
    tempRoom.style.width = "0px"
    tempRoom.style.height = "0px"
    this.viewportTarget.appendChild(tempRoom)

    this.interaction = {
      type: "draw",
      tempRoom,
      startVX: Math.round(vx),
      startVY: Math.round(vy)
    }
    this.canvasTarget.setPointerCapture(event.pointerId)
  }

  moveDraw(event) {
    const { tempRoom, startVX, startVY } = this.interaction
    const rect = this.canvasTarget.getBoundingClientRect()
    const sx = event.clientX - rect.left
    const sy = event.clientY - rect.top
    const { vx, vy } = screenToVirtual(sx, sy, this.scale, this.panX, this.panY)

    const x = Math.min(startVX, Math.round(vx))
    const y = Math.min(startVY, Math.round(vy))
    const w = Math.abs(Math.round(vx) - startVX)
    const h = Math.abs(Math.round(vy) - startVY)

    tempRoom.style.left = `${x}px`
    tempRoom.style.top = `${y}px`
    tempRoom.style.width = `${w}px`
    tempRoom.style.height = `${h}px`
  }

  async endDraw() {
    const { tempRoom } = this.interaction
    const w = parseInt(tempRoom.style.width)
    const h = parseInt(tempRoom.style.height)
    const x = parseInt(tempRoom.style.left)
    const y = parseInt(tempRoom.style.top)

    tempRoom.remove()
    this.drawMode = false
    this.canvasTarget.style.cursor = ""

    if (w < MIN_ROOM_SIZE || h < MIN_ROOM_SIZE) return

    const name = prompt("Room name:")
    if (!name) return

    try {
      const response = await authenticatedFetch("/rooms.json", {
        method: "POST",
        body: new URLSearchParams({
          "room[name]": name,
          "room[x]": x,
          "room[y]": y,
          "room[width]": w,
          "room[height]": h
        })
      })
      if (response.ok) {
        const room = await response.json()
        this.insertRoom(room)
      }
    } catch (e) {
      console.error("Failed to create room:", e)
    }
  }

  insertRoom({ id, name, x, y, width, height }) {
    const room = document.createElement("a")
    room.href = `/rooms/${id}/tasks`
    room.draggable = false
    room.dataset.turboFrame = "modal"
    room.dataset.roomId = id
    room.dataset.x = x
    room.dataset.y = y
    room.dataset.width = width
    room.dataset.height = height
    room.className = "floorplan-room absolute rounded-lg shadow-md flex flex-col items-center justify-center text-white font-bold select-none overflow-hidden hover:shadow-lg transition-shadow"
    room.style.cssText = `background: hsl(0, 0%, 80%); left: ${x}px; top: ${y}px; width: ${width}px; height: ${height}px;`

    const nameSpan = document.createElement("span")
    nameSpan.className = "truncate px-2 text-sm"
    nameSpan.textContent = name
    room.appendChild(nameSpan)

    const scoreSpan = document.createElement("span")
    scoreSpan.className = "text-xs opacity-75"
    scoreSpan.textContent = "--"
    room.appendChild(scoreSpan)

    this.viewportTarget.appendChild(room)
    this.addResizeHandles()
  }

  // --- Sidebar Drag & Drop ---

  sidebarDragStart(event) {
    const roomId = event.currentTarget.dataset.roomId
    event.dataTransfer.setData("text/room-id", roomId)
    event.dataTransfer.effectAllowed = "move"
  }

  handleDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  async handleDrop(event) {
    event.preventDefault()
    const roomId = event.dataTransfer.getData("text/room-id")
    if (!roomId) return

    const rect = this.canvasTarget.getBoundingClientRect()
    const sx = event.clientX - rect.left
    const sy = event.clientY - rect.top
    const { vx, vy } = screenToVirtual(sx, sy, this.scale, this.panX, this.panY)

    const x = Math.max(0, Math.min(VIRTUAL_SIZE - 150, Math.round(vx)))
    const y = Math.max(0, Math.min(VIRTUAL_SIZE - 100, Math.round(vy)))

    try {
      const response = await authenticatedFetch(`/rooms/${roomId}/position`, {
        method: "PATCH",
        body: new URLSearchParams({
          "room[x]": x,
          "room[y]": y,
          "room[width]": 150,
          "room[height]": 100
        })
      })
      if (response.ok) {
        Turbo.visit(window.location.href)
      }
    } catch (e) {
      console.error("Failed to place room:", e)
    }
  }

  // --- Debounced Save ---

  scheduleSave(roomEl) {
    const roomId = roomEl.dataset.roomId
    if (this.saveTimers[roomId]) clearTimeout(this.saveTimers[roomId])
    if (this.saveAbortControllers[roomId]) this.saveAbortControllers[roomId].abort()

    this.saveTimers[roomId] = setTimeout(() => {
      this.savePosition(roomEl)
      delete this.saveTimers[roomId]
    }, DEBOUNCE_MS)
  }

  async savePosition(roomEl, { keepalive = false } = {}) {
    const roomId = roomEl.dataset.roomId
    const { x, y, width, height } = roomEl.dataset

    const controller = new AbortController()
    this.saveAbortControllers[roomId] = controller

    try {
      const response = await authenticatedFetch(`/rooms/${roomId}/position`, {
        method: "PATCH",
        body: new URLSearchParams({
          "room[x]": x,
          "room[y]": y,
          "room[width]": width,
          "room[height]": height
        }),
        keepalive,
        signal: controller.signal
      })

      if (!response.ok) {
        console.error("Failed to save room position:", response.status)
      }
    } catch (e) {
      if (e.name !== "AbortError") {
        console.error("Failed to save room position:", e)
      }
    } finally {
      if (this.saveAbortControllers[roomId] === controller) {
        delete this.saveAbortControllers[roomId]
      }
    }
  }

  flushSaves() {
    for (const roomId of Object.keys(this.saveTimers)) {
      clearTimeout(this.saveTimers[roomId])
      const roomEl = this.canvasTarget.querySelector(`[data-room-id="${roomId}"]`)
      if (roomEl) this.savePosition(roomEl, { keepalive: true })
    }
    this.saveTimers = {}
  }

}
