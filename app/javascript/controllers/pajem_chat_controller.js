import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "panel", "btn", "messages", "input" ]

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    const activate = () => {
      this.btnTarget.style.viewTransitionName = ""
      this.panelTarget.style.viewTransitionName = "pajem-panel"
      this.panelTarget.hidden = false
      this.inputTarget.focus()
    }

    // Skip View Transition when a list is expanded to avoid conflicting active-card animation
    if (!document.startViewTransition || document.querySelector(".lists-page--expanded")) {
      activate()
      return
    }

    this.btnTarget.style.viewTransitionName = "pajem-panel"
    document.startViewTransition(activate)
  }

  close() {
    if (this.panelTarget.dataset.closing) return
    this.panelTarget.dataset.closing = "true"
    this.panelTarget.addEventListener("transitionend", () => {
      delete this.panelTarget.dataset.closing
      this.panelTarget.style.viewTransitionName = ""
      this.btnTarget.style.viewTransitionName = ""
      this.panelTarget.hidden = true
    }, { once: true })
  }

  onSubmitStart() {
    this.#addThinkingMessage()
    this.inputTarget.disabled = true
  }

  onSubmitEnd() {
    this.#removeThinkingMessage()
    this.inputTarget.disabled = false
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.#scrollToBottom()
  }

  #addThinkingMessage() {
    const div = document.createElement("div")
    div.id = "pajem-thinking"
    div.className = "pajem-chat__message pajem-chat__message--assistant pajem-chat__message--thinking"
    div.textContent = "Pajem está pensando…"
    this.messagesTarget.appendChild(div)
    this.#scrollToBottom()
  }

  #removeThinkingMessage() {
    document.getElementById("pajem-thinking")?.remove()
  }

  #scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
}
