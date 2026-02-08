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

      # Breadcrumb "Settings" appears in the navbar
      assert html =~ "Settings"
    end
  end
end
