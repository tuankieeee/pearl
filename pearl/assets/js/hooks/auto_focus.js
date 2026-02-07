const AutoFocusHook = {
  mounted() {
    this.handleEvent("focus-input", () => {
      this.el.focus()
    })
  }
}

export default AutoFocusHook
