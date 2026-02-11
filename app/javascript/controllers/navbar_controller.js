import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.hide = this.hide.bind(this)
    this.show = this.show.bind(this)
    this.resetTimer = this.resetTimer.bind(this)
    this.handleMouseMove = this.handleMouseMove.bind(this)

    this.events = ["scroll", "click", "touchstart"]
    this.events.forEach(event => document.addEventListener(event, this.resetTimer))
    document.addEventListener("mousemove", this.handleMouseMove)

    this.startTimer()
  }

  disconnect() {
    clearTimeout(this.timer)
    this.events.forEach(event => document.removeEventListener(event, this.resetTimer))
    document.removeEventListener("mousemove", this.handleMouseMove)
  }

  startTimer() {
    this.timer = setTimeout(this.hide, 3000)
  }

  resetTimer() {
    clearTimeout(this.timer)
    this.show()
    this.startTimer()
  }

  hide() {
    this.element.style.transform = "translateY(-100%)"
  }

  show() {
    this.element.style.transform = "translateY(0)"
  }

  handleMouseMove(event) {
    if (event.clientY <= 10) {
      this.resetTimer()
    }
  }
}
