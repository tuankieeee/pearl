defmodule PearlWeb.Plugs.Theme do
  @moduledoc """
  Plug to read theme preference from cookies and assign to conn.

  Valid themes: "retro" (light) and "luxury" (dark).
  When no cookie is set, theme is nil and daisyUI's --prefersdark handles system preference.
  """
  import Plug.Conn

  @cookie_name "theme"
  @valid_themes ["retro", "luxury"]

  def init(opts), do: opts

  def call(conn, _opts) do
    theme =
      conn
      |> fetch_cookies()
      |> Map.get(:cookies)
      |> Map.get(@cookie_name)
      |> validate_theme()

    assign(conn, :theme, theme)
  end

  # nil means no cookie set - let daisyUI's --prefersdark handle it
  defp validate_theme(nil), do: nil
  defp validate_theme(theme) when theme in @valid_themes, do: theme
  defp validate_theme(_), do: nil
end
