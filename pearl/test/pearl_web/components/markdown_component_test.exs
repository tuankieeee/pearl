defmodule PearlWeb.MarkdownComponentTest do
  use ExUnit.Case, async: true

  alias PearlWeb.MarkdownComponent

  describe "render_markdown/1" do
    test "converts markdown to HTML" do
      markdown = "# Hello\n\nThis is **bold**."
      html = MarkdownComponent.render_markdown(markdown)

      assert html =~ "<h1>"
      assert html =~ "Hello"
      assert html =~ "<strong>bold</strong>"
    end
  end

  describe "extract_mermaid/1" do
    test "extracts mermaid blocks" do
      markdown = """
      # Diagram

      ```mermaid
      graph TD
        A --> B
      ```
      """

      {html, mermaid_blocks} = MarkdownComponent.extract_mermaid(markdown)

      assert length(mermaid_blocks) == 1
      assert hd(mermaid_blocks) =~ "graph TD"
      assert html =~ "mermaid-placeholder"
    end
  end
end
