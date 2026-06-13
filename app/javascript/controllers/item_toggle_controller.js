import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "checkbox" ]

  optimistic() {
    const completed = this.element.classList.toggle("list-item--completed")
    this.checkboxTarget.classList.toggle("list-item__checkbox--checked", completed)
    this.checkboxTarget.textContent = completed ? "✓" : ""
    this.#updateProgressBar()
  }

  #updateProgressBar() {
    const container = this.element.closest("[id^='list_items_']")
    if (!container) return

    const listId = container.id.replace("list_items_", "")
    const total  = container.querySelectorAll(".list-item").length
    const done   = container.querySelectorAll(".list-item--completed").length
    const pct    = total > 0 ? Math.round(done / total * 100) : 0

    const fill = document.querySelector(`#progress_list_${listId}_panel .postit__progress-fill`)
    if (fill) fill.style.width = `${pct}%`
  }
}
