import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "trigger", "form", "input" ]

  open() {
    this.triggerTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.inputTarget.focus()
  }

  close() {
    this.triggerTarget.classList.remove("hidden")
    this.formTarget.classList.add("hidden")
    this.inputTarget.value = ""
  }

  handleKey(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }

    if (event.key === "Enter" && this.inputTarget.value.trim() === "") {
      event.preventDefault()
      this.close()
    }
  }
}
