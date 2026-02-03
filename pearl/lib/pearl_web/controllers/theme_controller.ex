defmodule PearlWeb.ThemeController do
  use PearlWeb, :controller

  @valid_themes ["retro", "synthwave"]

  def update(conn, %{"theme" => theme}) when theme in @valid_themes do
    conn
    |> put_resp_cookie("theme", theme, max_age: 365 * 24 * 60 * 60)
    |> redirect(to: get_referer(conn))
  end

  def update(conn, _params) do
    redirect(conn, to: "/")
  end

  defp get_referer(conn) do
    case get_req_header(conn, "referer") do
      [referer | _] -> URI.parse(referer).path || "/"
      [] -> "/"
    end
  end
end
