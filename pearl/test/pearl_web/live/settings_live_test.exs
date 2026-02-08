defmodule PearlWeb.SettingsLiveTest do
  use PearlWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "SettingsLive" do
    test "renders settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/settings")

      assert html =~ "Settings"
      assert html =~ "Settings coming soon"
    end

    test "has breadcrumb in navbar", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/settings")

      # Breadcrumb shows "/" separator followed by "Settings" text
      assert html =~ ~r|<span[^>]*>/</span>\s*<span[^>]*>Settings</span>|
    end
  end
end
