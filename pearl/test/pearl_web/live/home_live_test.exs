defmodule PearlWeb.HomeLiveTest do
  use PearlWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "HomeLive" do
    test "renders home page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Pearl"
      assert html =~ "Generate Wiki"
    end

    test "has repo URL input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      assert has_element?(view, "input[name='repo_url']")
    end

    test "does not show provider selection (configured via env)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      refute has_element?(view, "select[name='provider']")
      refute has_element?(view, "input[name='model']")
    end
  end
end
