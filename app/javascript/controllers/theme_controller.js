import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "icon" ]

  connect() {
    this.updateIcon()
  }

  toggle() {
    const html = document.documentElement
    const isDark = html.getAttribute("data-theme") === "dark"

    if (isDark) {
      html.removeAttribute("data-theme")
      localStorage.setItem("theme", "light")
    } else {
      html.setAttribute("data-theme", "dark")
      localStorage.setItem("theme", "dark")
    }

    this.updateIcon()
  }

  updateIcon() {
    if (!this.hasIconTarget) return
    const isDark = document.documentElement.getAttribute("data-theme") === "dark"
    this.iconTarget.textContent = isDark ? "☽" : "☀"
  }
}
