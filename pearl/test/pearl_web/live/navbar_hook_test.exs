defmodule PearlWeb.NavbarHookTest do
  use PearlWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pearl.Repositories

  describe "NavbarHook search" do
    test "search assigns are initialized", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # search_results starts empty, so no results menu should appear
      refute has_element?(view, "[class*='dropdown-content']", "Search")
    end

    test "searching returns matching repos", %{conn: conn} do
      {:ok, _} =
        Repositories.create_repo(%{
          url: "https://github.com/test/searchable",
          provider: "github",
          owner: "test",
          name: "searchable",
          status: "ready"
        })

      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("form[phx-change=search]")
        |> render_change(%{"q" => "searchable"})

      assert html =~ "test/searchable"
    end

    test "empty search clears results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html =
        view
        |> element("form[phx-change=search]")
        |> render_change(%{"q" => ""})

      refute html =~ "test/searchable"
    end
  end
end
