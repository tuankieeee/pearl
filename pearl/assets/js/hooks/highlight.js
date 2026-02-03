import hljs from "highlight.js/lib/core"

// Web
import javascript from "highlight.js/lib/languages/javascript"
import typescript from "highlight.js/lib/languages/typescript"
import xml from "highlight.js/lib/languages/xml"
import css from "highlight.js/lib/languages/css"
import json from "highlight.js/lib/languages/json"

// Backend
import python from "highlight.js/lib/languages/python"
import ruby from "highlight.js/lib/languages/ruby"
import go from "highlight.js/lib/languages/go"
import rust from "highlight.js/lib/languages/rust"
import java from "highlight.js/lib/languages/java"
import elixir from "highlight.js/lib/languages/elixir"
import php from "highlight.js/lib/languages/php"

// Config/Data
import yaml from "highlight.js/lib/languages/yaml"
import bash from "highlight.js/lib/languages/bash"
import sql from "highlight.js/lib/languages/sql"
import markdown from "highlight.js/lib/languages/markdown"

// Other
import c from "highlight.js/lib/languages/c"
import cpp from "highlight.js/lib/languages/cpp"
import csharp from "highlight.js/lib/languages/csharp"
import dockerfile from "highlight.js/lib/languages/dockerfile"
import graphql from "highlight.js/lib/languages/graphql"

// Register languages
hljs.registerLanguage("javascript", javascript)
hljs.registerLanguage("js", javascript)
hljs.registerLanguage("typescript", typescript)
hljs.registerLanguage("ts", typescript)
hljs.registerLanguage("html", xml)
hljs.registerLanguage("xml", xml)
hljs.registerLanguage("css", css)
hljs.registerLanguage("json", json)
hljs.registerLanguage("python", python)
hljs.registerLanguage("py", python)
hljs.registerLanguage("ruby", ruby)
hljs.registerLanguage("rb", ruby)
hljs.registerLanguage("go", go)
hljs.registerLanguage("rust", rust)
hljs.registerLanguage("rs", rust)
hljs.registerLanguage("java", java)
hljs.registerLanguage("elixir", elixir)
hljs.registerLanguage("ex", elixir)
hljs.registerLanguage("php", php)
hljs.registerLanguage("yaml", yaml)
hljs.registerLanguage("yml", yaml)
hljs.registerLanguage("bash", bash)
hljs.registerLanguage("sh", bash)
hljs.registerLanguage("shell", bash)
hljs.registerLanguage("sql", sql)
hljs.registerLanguage("markdown", markdown)
hljs.registerLanguage("md", markdown)
hljs.registerLanguage("c", c)
hljs.registerLanguage("cpp", cpp)
hljs.registerLanguage("csharp", csharp)
hljs.registerLanguage("cs", csharp)
hljs.registerLanguage("dockerfile", dockerfile)
hljs.registerLanguage("docker", dockerfile)
hljs.registerLanguage("graphql", graphql)
hljs.registerLanguage("gql", graphql)

const HighlightHook = {
  mounted() {
    this.highlightAll()
  },
  updated() {
    this.highlightAll()
  },
  highlightAll() {
    this.el.querySelectorAll("pre code").forEach((block) => {
      if (!block.dataset.highlighted) {
        hljs.highlightElement(block)
      }
    })
  }
}

export default HighlightHook
