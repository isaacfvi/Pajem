import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = [ "button", "input" ]

  copy() {
    navigator.clipboard.writeText(this.urlValue)
      .then(() => {
        const original = this.buttonTarget.textContent
        this.buttonTarget.textContent = "Copiado!"
        setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
      })
      .catch(() => { this.inputTarget.select() })
  }
}
