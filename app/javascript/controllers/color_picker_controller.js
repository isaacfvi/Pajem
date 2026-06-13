import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "toggle" ]

  connect() {
    this.#sync()
  }

  toggle() {
    this.#sync()
  }

  #sync() {
    this.inputTarget.disabled = !this.toggleTarget.checked
  }
}
