import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal", "contextName", "form", "token", "deleteLists" ]

  open(event) {
    const name = event.params.name
    const id   = event.params.id

    this.contextNameTarget.textContent = name
    this.formTarget.action = `/contextos/${id}`
    this.tokenTarget.value = document.querySelector('meta[name="csrf-token"]').content

    this.modalTarget.classList.remove("hidden")
  }

  close() {
    this.modalTarget.classList.add("hidden")
  }

  keep() {
    this.deleteListsTarget.value = "false"
    this.formTarget.requestSubmit()
  }

  remove() {
    this.deleteListsTarget.value = "true"
    this.formTarget.requestSubmit()
  }
}
