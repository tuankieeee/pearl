import mermaid from "mermaid"

let initialized = false

function ensureInitialized() {
  if (!initialized) {
    mermaid.initialize({
      startOnLoad: false,
      theme: "default",
      securityLevel: "loose"
    })
    initialized = true
  }
}

const MermaidHook = {
  mounted() {
    this.renderDiagram()
  },

  updated() {
    this.renderDiagram()
  },

  renderDiagram() {
    const content = this.el.dataset.mermaid
    if (!content) return

    ensureInitialized()

    const id = `mermaid-diagram-${this.el.id}`

    mermaid.render(id, content).then(({ svg }) => {
      this.el.innerHTML = svg
    }).catch(err => {
      console.error("Mermaid render error:", err)
      this.el.innerHTML = `<pre class="text-error text-sm whitespace-pre-wrap"><code>${content}</code></pre>`
    })
  }
}

export default MermaidHook
