defmodule PearlWeb.MarkdownComponent do
  @moduledoc """
  Component for rendering Markdown content with Mermaid diagram support.
  """

  use Phoenix.Component

  @mermaid_regex ~r/```mermaid\n([\s\S]*?)```/
  @mermaid_placeholder "MERMAID_BLOCK_PLACEHOLDER"

  @spec render_markdown(String.t()) :: String.t()
  def render_markdown(markdown) when is_binary(markdown) do
    markdown
    |> Earmark.as_html!(code_class_prefix: "language-")
    |> HtmlSanitizeEx.markdown_html()
  end

  def render_markdown(_), do: ""

  @spec extract_mermaid(String.t()) :: {String.t(), [String.t()]}
  def extract_mermaid(markdown) do
    mermaid_blocks = Regex.scan(@mermaid_regex, markdown) |> Enum.map(&Enum.at(&1, 1))

    html =
      markdown
      |> replace_mermaid_blocks()
      |> render_markdown()
      |> String.replace(@mermaid_placeholder, ~s(<div class="mermaid-placeholder"></div>))

    {html, mermaid_blocks}
  end

  defp replace_mermaid_blocks(markdown) do
    Regex.replace(@mermaid_regex, markdown, fn _, _content ->
      @mermaid_placeholder
    end)
  end

  attr :content, :string, required: true
  attr :class, :string, default: ""
  attr :id, :string, default: "markdown-content"

  def markdown(assigns) do
    {html, mermaid_blocks} = extract_mermaid(assigns.content || "")
    assigns = assign(assigns, html: html, mermaid_blocks: mermaid_blocks)

    ~H"""
    <div id={@id} phx-hook="Highlight" class={"prose prose-slate max-w-none #{@class}"}>
      {Phoenix.HTML.raw(@html)}
      <%= for {mermaid, index} <- Enum.with_index(@mermaid_blocks) do %>
        <div id={"mermaid-#{index}"} phx-hook="Mermaid" data-mermaid={mermaid} class="my-4">
          <pre class="mermaid"><%= mermaid %></pre>
        </div>
      <% end %>
    </div>
    """
  end
end
