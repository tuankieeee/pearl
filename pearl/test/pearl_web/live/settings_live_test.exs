defmodule PearlWeb.SettingsLiveTest do
  use PearlWeb.ConnCase

  import Mox
  import Phoenix.LiveViewTest

  alias Pearl.Repositories
  alias Pearl.Repositories.RepoRecord
  alias Pearl.Settings

  # Allow mock expectations from any process (for Task.Supervisor)
  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Settings.__reset__()
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

    test "shows inline error when embedding_batch_size is below minimum", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      html =
        view
        |> form("form[phx-submit=save]", settings: %{embedding_batch_size: "0"})
        |> render_submit()

      assert html =~ "must be between 1 and 500"
      assert html =~ "input-error"
    end

    test "shows inline error when embedding_batch_size is above maximum", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      html =
        view
        |> form("form[phx-submit=save]", settings: %{embedding_batch_size: "501"})
        |> render_submit()

      assert html =~ "must be between 1 and 500"
      assert html =~ "input-error"
    end

    test "shows inline error when file_read_concurrency is below minimum", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      html =
        view
        |> form("form[phx-submit=save]", settings: %{file_read_concurrency: "0"})
        |> render_submit()

      assert html =~ "must be between 1 and 100"
      assert html =~ "input-error"
    end

    test "shows inline error when file_read_concurrency is above maximum", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      html =
        view
        |> form("form[phx-submit=save]", settings: %{file_read_concurrency: "101"})
        |> render_submit()

      assert html =~ "must be between 1 and 100"
      assert html =~ "input-error"
    end

    test "shows inline error when wiki_page_timeout is below minimum", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      html =
        view
        |> form("form[phx-submit=save]", settings: %{wiki_page_timeout: "9999"})
        |> render_submit()

      assert html =~ "must be between 10000 and 600000"
      assert html =~ "input-error"
    end

    test "shows inline error when wiki_page_timeout is above maximum", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings")

      html =
        view
        |> form("form[phx-submit=save]", settings: %{wiki_page_timeout: "600001"})
        |> render_submit()

      assert html =~ "must be between 10000 and 600000"
      assert html =~ "input-error"
    end
  end

  describe "reindex_repos_task/1" do
    setup do
      # Use global mode for Task.Supervisor spawned processes
      set_mox_global()

      # Create a repo with ready status
      {:ok, repo} =
        Repositories.create_repo(%{
          url: "https://github.com/test/reindex",
          provider: "github",
          owner: "test",
          name: "reindex",
          status: RepoRecord.status_ready()
        })

      {:ok, repo: repo}
    end

    test "broadcasts :reindex_complete when all repos succeed", %{repo: repo} do
      topic = "settings:reindex:test-success"
      Phoenix.PubSub.subscribe(Pearl.PubSub, topic)

      # Mock successful index_repo call (1-arity version)
      expect(Pearl.RagMock, :index_repo, fn ^repo -> {:ok, 42} end)

      assert :ok = PearlWeb.SettingsLive.reindex_repos_task(topic)

      assert_receive {:reindex_progress, "reindex", 1, 1}
      assert_receive :reindex_complete
    end

    test "broadcasts :reindex_failed with error messages when repos fail", %{repo: repo} do
      topic = "settings:reindex:test-failure"
      Phoenix.PubSub.subscribe(Pearl.PubSub, topic)

      # Mock failed index_repo call (1-arity version)
      expect(Pearl.RagMock, :index_repo, fn ^repo -> {:error, :embedding_failed} end)

      assert :ok = PearlWeb.SettingsLive.reindex_repos_task(topic)

      assert_receive {:reindex_progress, "reindex", 1, 1}
      assert_receive {:reindex_failed, error_messages}
      assert ["reindex: :embedding_failed"] = error_messages
    end

    test "handles mixed success and failure across multiple repos" do
      # Create a second repo
      {:ok, repo2} =
        Repositories.create_repo(%{
          url: "https://github.com/test/reindex2",
          provider: "github",
          owner: "test",
          name: "reindex2",
          status: RepoRecord.status_ready()
        })

      topic = "settings:reindex:test-mixed"
      Phoenix.PubSub.subscribe(Pearl.PubSub, topic)

      # First call succeeds, second fails (1-arity version)
      Pearl.RagMock
      |> expect(:index_repo, fn _repo -> {:ok, 10} end)
      |> expect(:index_repo, fn _repo -> {:error, :connection_timeout} end)

      assert :ok = PearlWeb.SettingsLive.reindex_repos_task(topic)

      # Should receive progress for both repos
      assert_receive {:reindex_progress, _, 1, 2}
      assert_receive {:reindex_progress, _, 2, 2}

      # Should broadcast failure with the error
      assert_receive {:reindex_failed, error_messages}
      assert length(error_messages) == 1
      assert hd(error_messages) =~ ":connection_timeout"

      # Cleanup
      Repositories.delete_repo(repo2)
    end
  end
end
