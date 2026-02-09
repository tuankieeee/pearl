defmodule PearlWeb.SettingsLiveTest do
  use PearlWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pearl.Settings

  setup do
    Settings.reset()
    :ok
  end

  describe "SettingsLive" do
    test "renders settings page with all sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/settings")

      assert html =~ "Settings"
      assert html =~ "LLM Providers"
      assert html =~ "Performance"
      assert html =~ "Storage"
    end

    test "shows current settings values", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/settings")

      assert html =~ "openrouter"
      assert html =~ "openai/gpt-5.2"
      assert html =~ "openai/text-embedding-3-small"
    end

    test "has provider select dropdowns", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      assert has_element?(view, "select[name='settings[chat_provider]']")
      assert has_element?(view, "select[name='settings[embedding_provider]']")
    end

    test "has model text inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      assert has_element?(view, "input[name='settings[chat_model]']")
      assert has_element?(view, "input[name='settings[embedding_model]']")
    end

    test "has credential env var inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      assert has_element?(view, "input[name='settings[openrouter_api_key_env]']")
      assert has_element?(view, "input[name='settings[ollama_host_env]']")
    end

    test "has performance inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      assert has_element?(view, "input[name='settings[embedding_batch_size]']")
      assert has_element?(view, "input[name='settings[file_read_concurrency]']")
      assert has_element?(view, "input[name='settings[wiki_page_timeout]']")
    end

    test "has storage path input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      assert has_element?(view, "input[name='settings[repos_path]']")
    end

    test "has save button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      assert has_element?(view, "button", "Save Settings")
    end

    test "has breadcrumb in navbar", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/settings")

      assert html =~ ~r|<span[^>]*>/</span>\s*<span[^>]*>Settings</span>|
    end
  end

  describe "saving settings" do
    test "saves settings and shows flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      html =
        view
        |> form("form[phx-submit=save]", settings: %{chat_model: "test/model-123"})
        |> render_submit()

      assert html =~ "Settings saved"
    end

    test "persists settings to database", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      view
      |> form("form[phx-submit=save]", settings: %{chat_model: "test/model-456"})
      |> render_submit()

      assert Settings.get("chat_model") == "test/model-456"
    end
  end
end
