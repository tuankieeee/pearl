import mermaid from "mermaid"

mermaid.initialize({
  startOnLoad: false,
  theme: "default",
  securityLevel: "loose"
})

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

    const id = `mermaid-diagram-${this.el.id}`

    try {
      mermaid.render(id, content).then(({ svg }) => {
        this.el.innerHTML = svg
      }).catch(err => {
        console.error("Mermaid render error:", err)
        this.el.innerHTML = `<pre class="text-red-500">Diagram error: ${err.message}</pre>`
      })
    } catch (err) {
      console.error("Mermaid error:", err)
      this.el.innerHTML = `<pre class="text-red-500">Diagram error: ${err.message}</pre>`
    }
  }
}

export default MermaidHook
