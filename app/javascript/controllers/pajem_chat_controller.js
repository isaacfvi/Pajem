import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "panel", "btn" ]

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    const activate = () => {
      this.btnTarget.style.viewTransitionName = ""
      this.panelTarget.style.viewTransitionName = "pajem-panel"
      this.panelTarget.hidden = false
    }

    if (!document.startViewTransition) { activate(); return }

    this.btnTarget.style.viewTransitionName = "pajem-panel"
    document.startViewTransition(activate)
  }

  close() {
    const deactivate = () => {
      this.panelTarget.style.viewTransitionName = ""
      this.panelTarget.hidden = true
      this.btnTarget.style.viewTransitionName = "pajem-panel"
    }

    if (!document.startViewTransition) {
      this.panelTarget.hidden = true
      return
    }

    this.panelTarget.style.viewTransitionName = "pajem-panel"
    const transition = document.startViewTransition(deactivate)
    transition.finished.then(() => {
      this.btnTarget.style.viewTransitionName = ""
    })
  }
}
