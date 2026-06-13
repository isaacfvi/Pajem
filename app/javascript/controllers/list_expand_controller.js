import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "grid", "panel", "gridHeader" ]

  #activeCard = null

  expand(event) {
    const listId = String(event.params.listId)
    const card = event.currentTarget
    this.#activeCard = card

    const activate = () => {
      card.style.viewTransitionName = ""
      this.gridTarget.classList.add("hidden")
      this.gridHeaderTarget.classList.add("hidden")
      this.element.classList.add("lists-page--expanded")

      const panel = this.panelTargets.find(p => p.dataset.listId === listId)
      if (panel) { panel.style.viewTransitionName = "active-card"; panel.classList.remove("hidden") }
    }

    if (!document.startViewTransition) { activate(); return }

    card.style.viewTransitionName = "active-card"
    document.startViewTransition(activate)
  }

  noop() {}

  collapse() {
    const panel = this.panelTargets.find(p => !p.classList.contains("hidden"))

    const deactivate = () => {
      if (panel) panel.style.viewTransitionName = ""
      this.element.classList.remove("lists-page--expanded")
      this.gridTarget.classList.remove("hidden")
      this.gridHeaderTarget.classList.remove("hidden")
      this.panelTargets.forEach(p => p.classList.add("hidden"))
      if (this.#activeCard) this.#activeCard.style.viewTransitionName = "active-card"
    }

    if (!document.startViewTransition || !panel) {
      deactivate()
      this.#activeCard = null
      return
    }

    panel.style.viewTransitionName = "active-card"
    const transition = document.startViewTransition(deactivate)
    transition.finished.then(() => {
      if (this.#activeCard) this.#activeCard.style.viewTransitionName = ""
      this.#activeCard = null
    })
  }
}
