import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.showModal()
  }

  close() {
    this.element.close()
    const frame = document.getElementById("modal")
    frame.removeAttribute("src")
    frame.innerHTML = ""
  }

  clickOutside(event) {
    if (event.target === this.element) {
      this.close()
    }
  }
}
