# Settings Page & Configuration Cleanup — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace env-var-only configuration with a database-backed settings system and a LiveView settings page, splitting chat and embedding providers for independent configuration.

**Architecture:** A `settings` table stores key-value pairs. An ETS-cached `Pearl.Settings` context reads/writes them. `Pearl.Config` is rewritten to read from Settings (ETS) → env var → hardcoded default. The `Providers` facade and all callers (`Rag`, `Wiki`) are updated to use split `chat_provider`/`embedding_provider` config. A LiveView settings page at `/settings` replaces the current stub.

**Tech Stack:** Elixir/Phoenix, Ecto + PostgreSQL, ETS for caching, Phoenix LiveView 1.1, daisyUI

**Design doc:** `docs/plans/2026-02-08-settings-page-design.md`

---

## Task 1: Settings Schema + Migration

**Files:**
- Create: `pearl/priv/repo/migrations/TIMESTAMP_create_settings.exs`
- Create: `pearl/lib/pearl/settings/setting.ex`
- Test: `pearl/test/pearl/settings/setting_test.exs`

**Step 1: Write the failing test**

```elixir
# test/pearl/settings/setting_test.exs
defmodule Pearl.Settings.SettingTest do
  use Pearl.DataCase

  alias Pearl.Settings.Setting

  describe "changeset/2" do
    test "valid with key and value" do
      changeset = Setting.changeset(%Setting{}, %{key: "chat_provider", value: "openrouter"})
      assert changeset.valid?
    end

    test "invalid without key" do
      changeset = Setting.changeset(%Setting{}, %{value: "openrouter"})
      refute changeset.valid?
      assert %{key: ["can't be blank"]} = errors_on(changeset)
    end

    test "valid with nil value (uses default)" do
      changeset = Setting.changeset(%Setting{}, %{key: "chat_provider", value: nil})
      assert changeset.valid?
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/pearl/settings/setting_test.exs -v`
Expected: FAIL — `Pearl.Settings.Setting` module not found

**Step 3: Create the migration**

Run: `mix ecto.gen.migration create_settings`

Then write the migration:

```elixir
defmodule Pearl.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :key, :string, null: false
      add :value, :string

      timestamps()
    end

    create unique_index(:settings, [:key])
  end
end
```

**Step 4: Write the schema**

```elixir
# lib/pearl/settings/setting.ex
defmodule Pearl.Settings.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :key, :string
    field :value, :string

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
```

**Step 5: Run migration and test**

Run: `mix ecto.migrate && mix test test/pearl/settings/setting_test.exs -v`
Expected: 3 tests PASS

**Step 6: Commit**

```bash
git add pearl/priv/repo/migrations/*_create_settings.exs pearl/lib/pearl/settings/setting.ex pearl/test/pearl/settings/setting_test.exs
git commit -m "feat(settings): add settings schema and migration"
```

---

## Task 2: Settings Context with ETS Cache

**Files:**
- Create: `pearl/lib/pearl/settings/settings.ex`
- Test: `pearl/test/pearl/settings/settings_test.exs`

**Step 1: Write the failing test**

```elixir
# test/pearl/settings/settings_test.exs
defmodule Pearl.Settings.SettingsTest do
  use Pearl.DataCase

  alias Pearl.Settings

  # Defaults from the design doc
  @defaults %{
    "chat_provider" => "openrouter",
    "chat_model" => "openai/gpt-5.2",
    "embedding_provider" => "openrouter",
    "embedding_model" => "openai/text-embedding-3-small",
    "openrouter_api_key_env" => "OPENROUTER_API_KEY",
    "ollama_host_env" => "OLLAMA_HOST",
    "embedding_batch_size" => "100",
    "file_read_concurrency" => "10",
    "wiki_page_timeout" => "300000",
    "repos_path" => "~/.pearl/repos"
  }

  setup do
    # Ensure ETS table is initialized for each test
    Settings.init()
    :ok
  end

  describe "get/1" do
    test "returns default when no DB row exists" do
      assert Settings.get("chat_provider") == "openrouter"
      assert Settings.get("chat_model") == "openai/gpt-5.2"
      assert Settings.get("embedding_model") == "openai/text-embedding-3-small"
    end

    test "returns DB value when row exists" do
      Settings.put("chat_model", "anthropic/claude-opus-4-6")
      assert Settings.get("chat_model") == "anthropic/claude-opus-4-6"
    end

    test "returns nil for unknown key" do
      assert Settings.get("nonexistent_key") == nil
    end
  end

  describe "put/2" do
    test "inserts a new setting" do
      assert :ok = Settings.put("chat_provider", "ollama")
      assert Settings.get("chat_provider") == "ollama"
    end

    test "updates an existing setting" do
      Settings.put("chat_model", "model-a")
      Settings.put("chat_model", "model-b")
      assert Settings.get("chat_model") == "model-b"
    end
  end

  describe "all/0" do
    test "returns all settings merged with defaults" do
      Settings.put("chat_provider", "ollama")
      all = Settings.all()

      # Overridden value
      assert all["chat_provider"] == "ollama"
      # Default value
      assert all["chat_model"] == "openai/gpt-5.2"
    end
  end

  describe "defaults/0" do
    test "returns all default keys" do
      defaults = Settings.defaults()
      assert defaults == @defaults
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/pearl/settings/settings_test.exs -v`
Expected: FAIL — `Pearl.Settings` module not found

**Step 3: Write the Settings context**

```elixir
# lib/pearl/settings/settings.ex
defmodule Pearl.Settings do
  @moduledoc """
  Context for managing application settings.

  Settings are stored in the database and cached in ETS for fast reads.
  The lookup chain: ETS cache (from DB) → hardcoded default.
  """

  import Ecto.Query
  alias Pearl.Repo
  alias Pearl.Settings.Setting

  @table :pearl_settings

  @defaults %{
    "chat_provider" => "openrouter",
    "chat_model" => "openai/gpt-5.2",
    "embedding_provider" => "openrouter",
    "embedding_model" => "openai/text-embedding-3-small",
    "openrouter_api_key_env" => "OPENROUTER_API_KEY",
    "ollama_host_env" => "OLLAMA_HOST",
    "embedding_batch_size" => "100",
    "file_read_concurrency" => "10",
    "wiki_page_timeout" => "300000",
    "repos_path" => "~/.pearl/repos"
  }

  @doc "Returns the defaults map."
  def defaults, do: @defaults

  @doc "Initialize ETS table and load settings from DB."
  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table])
    else
      :ets.delete_all_objects(@table)
    end

    load_from_db()
  end

  @doc "Get a setting value. Checks ETS cache, then falls back to default."
  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      [] -> Map.get(@defaults, key)
    end
  end

  @doc "Set a setting value. Writes to DB and updates ETS cache."
  def put(key, value) do
    %Setting{}
    |> Setting.changeset(%{key: key, value: value})
    |> Repo.insert(
      on_conflict: [set: [value: value, updated_at: DateTime.utc_now()]],
      conflict_target: :key
    )

    :ets.insert(@table, {key, value})
    :ok
  end

  @doc "Returns all settings merged with defaults (defaults first, DB overrides)."
  def all do
    db_settings = :ets.tab2list(@table) |> Map.new()
    Map.merge(@defaults, db_settings)
  end

  defp load_from_db do
    Setting
    |> select([s], {s.key, s.value})
    |> Repo.all()
    |> Enum.each(fn {key, value} ->
      :ets.insert(@table, {key, value})
    end)
  end
end
```

**Step 4: Run tests**

Run: `mix test test/pearl/settings/settings_test.exs -v`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add pearl/lib/pearl/settings/settings.ex pearl/test/pearl/settings/settings_test.exs
git commit -m "feat(settings): add Settings context with ETS cache"
```

---

## Task 3: Initialize ETS on Application Start

**Files:**
- Modify: `pearl/lib/pearl/application.ex:11-20` (add Settings init to supervision tree)

**Step 1: Write a test for initialization**

This is a lightweight integration check — after the app starts, `Settings.get/1` should work.

```elixir
# Add to test/pearl/settings/settings_test.exs
describe "application startup" do
  test "settings are accessible after app starts" do
    # App is already started by test_helper.exs
    # Just verify get/1 works without calling init manually
    assert is_binary(Pearl.Settings.get("chat_provider"))
  end
end
```

**Step 2: Add init call to application.ex**

In `pearl/lib/pearl/application.ex`, add `Pearl.Settings.init()` after the Repo starts. The simplest approach: add a `Task` child that runs init, placed after `Pearl.Repo` in the children list.

Actually, the cleanest way: call `Settings.init()` in the `start/2` function after `Supervisor.start_link`, since the Repo is already started at that point. But that's fragile. Better: use a simple GenServer or a `{Task, fn -> Settings.init() end}` child placed after Repo.

```elixir
# In the children list, after Pearl.Repo:
children = [
  PearlWeb.Telemetry,
  Pearl.Repo,
  {Task, &Pearl.Settings.init/0},  # <-- add this line
  {DNSCluster, query: Application.get_env(:pearl, :dns_cluster_query) || :ignore},
  {Phoenix.PubSub, name: Pearl.PubSub},
  {Task.Supervisor, name: Pearl.TaskSupervisor},
  PearlWeb.Endpoint
]
```

**Step 3: Run tests**

Run: `mix test test/pearl/settings/settings_test.exs -v`
Expected: All tests PASS (including the new startup test)

**Step 4: Commit**

```bash
git add pearl/lib/pearl/application.ex pearl/test/pearl/settings/settings_test.exs
git commit -m "feat(settings): initialize ETS cache on application start"
```

---

## Task 4: Rewrite Pearl.Config to Use Settings

**Files:**
- Modify: `pearl/lib/pearl/config.ex` (rewrite all functions)
- Create: `pearl/test/pearl/config_test.exs`

This is the critical task. `Pearl.Config` currently reads from `Application.get_env`. It needs to read from `Pearl.Settings.get/1` instead, and split the single `provider()` into `chat_provider()` and `embedding_provider()`.

**Step 1: Write the failing tests**

```elixir
# test/pearl/config_test.exs
defmodule Pearl.ConfigTest do
  use Pearl.DataCase

  alias Pearl.Config
  alias Pearl.Settings

  setup do
    Settings.init()
    :ok
  end

  describe "chat_provider/0" do
    test "returns default provider as atom" do
      assert Config.chat_provider() == :openrouter
    end

    test "returns overridden provider" do
      Settings.put("chat_provider", "ollama")
      assert Config.chat_provider() == :ollama
    end
  end

  describe "chat_model/0" do
    test "returns default model" do
      assert Config.chat_model() == "openai/gpt-5.2"
    end

    test "returns overridden model" do
      Settings.put("chat_model", "anthropic/claude-opus-4-6")
      assert Config.chat_model() == "anthropic/claude-opus-4-6"
    end
  end

  describe "embedding_provider/0" do
    test "returns default provider as atom" do
      assert Config.embedding_provider() == :openrouter
    end

    test "returns overridden provider" do
      Settings.put("embedding_provider", "ollama")
      assert Config.embedding_provider() == :ollama
    end
  end

  describe "embedding_model/0" do
    test "returns default model" do
      assert Config.embedding_model() == "openai/text-embedding-3-small"
    end
  end

  describe "embedding_batch_size/0" do
    test "returns integer" do
      assert Config.embedding_batch_size() == 100
    end
  end

  describe "openrouter_api_key/0" do
    test "reads from env var named in settings" do
      # The default env var name is OPENROUTER_API_KEY
      # We can't easily test the actual env var lookup,
      # but we can test the indirection
      Settings.put("openrouter_api_key_env", "MY_CUSTOM_KEY_VAR")
      assert Config.openrouter_api_key_env() == "MY_CUSTOM_KEY_VAR"
    end
  end

  describe "ollama_host/0" do
    test "reads from env var named in settings" do
      Settings.put("ollama_host_env", "MY_OLLAMA_HOST")
      assert Config.ollama_host() == System.get_env("MY_OLLAMA_HOST")
    end

    test "returns default when env var not set" do
      Settings.put("ollama_host_env", "NONEXISTENT_VAR_12345")
      assert Config.ollama_host() == "http://localhost:11434"
    end
  end

  describe "repos_path/0" do
    test "returns default path" do
      assert Config.repos_path() == "~/.pearl/repos"
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/pearl/config_test.exs -v`
Expected: FAIL — functions like `chat_provider/0` don't exist

**Step 3: Rewrite Pearl.Config**

```elixir
# lib/pearl/config.ex
defmodule Pearl.Config do
  @moduledoc """
  Centralized configuration for Pearl.

  Reads settings from `Pearl.Settings` (ETS-cached, DB-backed).
  Provides typed accessors for all configuration values.
  """

  alias Pearl.Settings

  # --- Chat / Generation ---

  @spec chat_provider() :: :ollama | :openrouter
  def chat_provider do
    case Settings.get("chat_provider") do
      "ollama" -> :ollama
      _ -> :openrouter
    end
  end

  @spec chat_model() :: String.t()
  def chat_model do
    Settings.get("chat_model")
  end

  # --- Embeddings ---

  @spec embedding_provider() :: :ollama | :openrouter
  def embedding_provider do
    case Settings.get("embedding_provider") do
      "ollama" -> :ollama
      _ -> :openrouter
    end
  end

  @spec embedding_model() :: String.t()
  def embedding_model do
    Settings.get("embedding_model")
  end

  # --- Provider credentials (env var indirection) ---

  @spec openrouter_api_key_env() :: String.t()
  def openrouter_api_key_env do
    Settings.get("openrouter_api_key_env")
  end

  @spec openrouter_api_key() :: String.t() | nil
  def openrouter_api_key do
    System.get_env(openrouter_api_key_env())
  end

  @spec ollama_host() :: String.t()
  def ollama_host do
    env_var = Settings.get("ollama_host_env")
    System.get_env(env_var) || "http://localhost:11434"
  end

  # --- Performance ---

  @spec embedding_batch_size() :: pos_integer()
  def embedding_batch_size do
    Settings.get("embedding_batch_size") |> String.to_integer()
  end

  @spec file_read_concurrency() :: pos_integer()
  def file_read_concurrency do
    Settings.get("file_read_concurrency") |> String.to_integer()
  end

  @spec wiki_page_timeout() :: pos_integer()
  def wiki_page_timeout do
    Settings.get("wiki_page_timeout") |> String.to_integer()
  end

  # --- Storage ---

  @spec repos_path() :: String.t()
  def repos_path do
    Settings.get("repos_path")
  end
end
```

**Step 4: Run tests**

Run: `mix test test/pearl/config_test.exs -v`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add pearl/lib/pearl/config.ex pearl/test/pearl/config_test.exs
git commit -m "feat(settings): rewrite Config to read from Settings context"
```

---

## Task 5: Update Provider Modules to Use New Config

**Files:**
- Modify: `pearl/lib/pearl/providers/openrouter.ex:185-192` (api_key and embedding_model)
- Modify: `pearl/lib/pearl/providers/ollama.ex:17-20,149-153` (base_url and embedding_model)
- Modify: `pearl/lib/pearl/rag/rag.ex:66,112,158,182` (split provider usage)
- Modify: `pearl/lib/pearl/wiki/wiki.ex:21-22` (split provider usage)

This task updates all callers to use the new split `chat_provider`/`embedding_provider` config.

**Step 1: Update OpenRouter provider**

In `pearl/lib/pearl/providers/openrouter.ex`, change:

```elixir
# Line 185-187: Replace api_key function
defp api_key do
  Pearl.Config.openrouter_api_key()
end

# Lines 189-192: Replace embedding_model function
@impl true
def embedding_model do
  Pearl.Config.embedding_model()
end
```

**Step 2: Update Ollama provider**

In `pearl/lib/pearl/providers/ollama.ex`, change:

```elixir
# Lines 17-20: Replace base_url function
def base_url do
  Pearl.Config.ollama_host()
end

# Lines 149-153: Replace embedding_model function
@impl true
def embedding_model do
  Pearl.Config.embedding_model()
end
```

**Step 3: Update Rag context — split provider calls**

In `pearl/lib/pearl/rag/rag.ex`:

Line 66 — embedding model tracking (stays the same, already uses `Config.embedding_model()`):
```elixir
Repositories.update_repo(repo, %{embedding_model: Config.embedding_model()})
```

Line 112 — embed calls should use `embedding_provider`:
```elixir
# Change: Config.provider() → Config.embedding_provider()
case Providers.embed(Config.embedding_provider(), texts) do
```

Line 158 — question embedding should use `embedding_provider`:
```elixir
# Change: Config.provider() → Config.embedding_provider()
with {:ok, [query_vector]} <- Providers.embed(Config.embedding_provider(), [question]) do
```

Line 182 — chat calls should use `chat_provider` and `chat_model`:
```elixir
# Change: Config.provider() → Config.chat_provider(), Config.model() → Config.chat_model()
Providers.chat(Config.chat_provider(), Config.chat_model(), messages, opts)
```

**Step 4: Update Wiki context**

In `pearl/lib/pearl/wiki/wiki.ex`, lines 21-27:

```elixir
# Change: Config.provider() → Config.chat_provider(), Config.model() → Config.chat_model()
def generate(repo, on_progress \\ fn _ -> :ok end) do
  provider = Config.chat_provider()
  model = Config.chat_model()

  case Generator.generate(repo, provider, model, on_progress) do
    {:ok, wiki_data} ->
      wiki_data = Map.put(wiki_data, :model_used, "#{Config.chat_provider()}/#{Config.chat_model()}")
```

**Step 5: Run all tests**

Run: `mix test -v`
Expected: All tests PASS. Some tests may need adjustment if they mock `Config.provider()` — rename those calls to `Config.chat_provider()`.

**Step 6: Commit**

```bash
git add pearl/lib/pearl/providers/openrouter.ex pearl/lib/pearl/providers/ollama.ex pearl/lib/pearl/rag/rag.ex pearl/lib/pearl/wiki/wiki.ex
git commit -m "refactor(config): update providers and contexts to use split chat/embedding config"
```

---

## Task 6: Clean Up runtime.exs

**Files:**
- Modify: `pearl/config/runtime.exs:24-36` (remove LLM config that's now in Settings)
- Modify: `pearl/config/config.exs:61-73` (remove provider defaults that moved to Settings)

Now that settings live in the DB, we can remove the LLM-specific env var reads from `runtime.exs`. Keep only the Phoenix/Ecto/prod infrastructure config.

**Step 1: Clean up runtime.exs**

Remove lines 24-36 (the `llm_provider`, `llm_model`, `embedding_model`, `embedding_batch_size`, `file_read_concurrency` config block).

Remove lines 106-118 (the `:providers` and `:storage` config blocks) — these are now managed by `Settings`.

**Keep:** `PORT`, `PHX_SERVER`, `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `DNS_CLUSTER_QUERY`, `POOL_SIZE`, `ECTO_IPV6` — these are infrastructure/deploy config, not application settings.

**Step 2: Clean up config.exs**

Remove lines 61-73 (the `:providers` and `:storage` config blocks).

**Step 3: Run all tests**

Run: `mix test -v`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add pearl/config/runtime.exs pearl/config/config.exs
git commit -m "refactor(config): remove LLM env vars from runtime.exs, now in Settings"
```

---

## Task 7: Settings LiveView — Form Rendering

**Files:**
- Modify: `pearl/lib/pearl_web/live/settings_live.ex` (replace stub)
- Modify: `pearl/test/pearl_web/live/settings_live_test.exs` (replace stub test)

**Step 1: Write the failing tests**

```elixir
# test/pearl_web/live/settings_live_test.exs
defmodule PearlWeb.SettingsLiveTest do
  use PearlWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pearl.Settings

  setup do
    Settings.init()
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
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/pearl_web/live/settings_live_test.exs -v`
Expected: FAIL — page still shows "Settings coming soon"

**Step 3: Implement the LiveView**

Replace `pearl/lib/pearl_web/live/settings_live.ex` with the full implementation. This is the largest file. Key structure:

- `mount/3` — loads all current settings into assigns, computes env var status and path status
- `render/1` — three cards (LLM Providers, Performance, Storage) + save footer
- `handle_event("validate", ...)` — marks form dirty, updates live feedback (env var badges, path resolution)
- `handle_event("save", ...)` — detects embedding config changes, either saves directly or shows modal
- `handle_event("save_and_reindex", ...)` — saves + triggers re-index of all repos
- `handle_event("save_without_reindex", ...)` — saves without re-indexing

```elixir
# lib/pearl_web/live/settings_live.ex
defmodule PearlWeb.SettingsLive do
  use PearlWeb, :live_view

  alias Pearl.Settings

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.all()

    {:ok,
     assign(socket,
       page_title: "Settings",
       drawer_id: nil,
       breadcrumb: "Settings",
       show_ask: false,
       settings: settings,
       initial_settings: settings,
       dirty: false,
       embedding_changed: false,
       openrouter_key_set: env_var_set?(settings["openrouter_api_key_env"]),
       ollama_host_set: env_var_set?(settings["ollama_host_env"]),
       resolved_path: Path.expand(settings["repos_path"]),
       path_exists: File.dir?(Path.expand(settings["repos_path"]))
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <div class="max-w-3xl mx-auto py-12 px-4 space-y-8">
        <div class="animate-fade-up">
          <h1 class="text-2xl font-bold tracking-tight">Settings</h1>
          <p class="text-base-content/50 text-sm mt-1">
            Configure LLM providers, performance tuning, and storage paths.
          </p>
        </div>

        <.form for={%{}} as={:settings} phx-change="validate" phx-submit="save">
          <%!-- Card 1: LLM Providers --%>
          <div class="card bg-base-100 shadow-md animate-fade-up" style="animation-delay: 75ms">
            <div class="card-body">
              <h2 class="card-title text-lg">
                <.icon name="hero-cpu-chip" class="size-5 text-primary" />
                LLM Providers
              </h2>
              <p class="text-sm text-base-content/50 -mt-1">
                Select which providers and models to use for wiki generation and embeddings.
              </p>

              <div class="divider my-2"></div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <%!-- Chat / Generation --%>
                <fieldset>
                  <legend class="text-xs font-semibold uppercase tracking-wider text-base-content/40 mb-3">
                    Chat / Generation
                  </legend>

                  <div class="form-control mb-3">
                    <label class="label" for="chat_provider">
                      <span class="label-text text-sm">Provider</span>
                    </label>
                    <select
                      name="settings[chat_provider]"
                      id="chat_provider"
                      class="select select-bordered select-sm w-full"
                    >
                      <option value="openrouter" selected={@settings["chat_provider"] == "openrouter"}>
                        OpenRouter
                      </option>
                      <option value="ollama" selected={@settings["chat_provider"] == "ollama"}>
                        Ollama (Local)
                      </option>
                    </select>
                  </div>

                  <div class="form-control">
                    <label class="label" for="chat_model">
                      <span class="label-text text-sm">Model</span>
                    </label>
                    <input
                      type="text"
                      name="settings[chat_model]"
                      id="chat_model"
                      value={@settings["chat_model"]}
                      placeholder="e.g. openai/gpt-5.2"
                      class="input input-bordered input-sm w-full font-mono text-xs"
                    />
                  </div>
                </fieldset>

                <%!-- Embeddings --%>
                <fieldset>
                  <legend class="text-xs font-semibold uppercase tracking-wider text-base-content/40 mb-3">
                    Embeddings
                  </legend>

                  <div class="form-control mb-3">
                    <label class="label" for="embedding_provider">
                      <span class="label-text text-sm">Provider</span>
                    </label>
                    <select
                      name="settings[embedding_provider]"
                      id="embedding_provider"
                      class="select select-bordered select-sm w-full"
                    >
                      <option
                        value="openrouter"
                        selected={@settings["embedding_provider"] == "openrouter"}
                      >
                        OpenRouter
                      </option>
                      <option value="ollama" selected={@settings["embedding_provider"] == "ollama"}>
                        Ollama (Local)
                      </option>
                    </select>
                  </div>

                  <div class="form-control">
                    <label class="label" for="embedding_model">
                      <span class="label-text text-sm">Model</span>
                    </label>
                    <input
                      type="text"
                      name="settings[embedding_model]"
                      id="embedding_model"
                      value={@settings["embedding_model"]}
                      placeholder="e.g. openai/text-embedding-3-small"
                      class="input input-bordered input-sm w-full font-mono text-xs"
                    />
                  </div>
                </fieldset>
              </div>

              <div class="divider my-2"></div>

              <%!-- Credentials --%>
              <div>
                <h3 class="text-xs font-semibold uppercase tracking-wider text-base-content/40 mb-3">
                  Provider Credentials
                </h3>
                <p class="text-xs text-base-content/40 mb-4">
                  Pearl reads API keys from environment variables. Configure which env var names to look up.
                </p>

                <div class="space-y-3">
                  <div class="flex items-end gap-3">
                    <div class="form-control flex-1">
                      <label class="label" for="openrouter_api_key_env">
                        <span class="label-text text-sm">OpenRouter API Key</span>
                      </label>
                      <input
                        type="text"
                        name="settings[openrouter_api_key_env]"
                        id="openrouter_api_key_env"
                        value={@settings["openrouter_api_key_env"]}
                        class="input input-bordered input-sm w-full font-mono text-xs"
                      />
                    </div>
                    <div class="pb-1">
                      <span
                        :if={@openrouter_key_set}
                        class="badge badge-success badge-sm gap-1"
                      >
                        <.icon name="hero-check-circle-mini" class="size-3" /> Set
                      </span>
                      <span
                        :if={!@openrouter_key_set}
                        class="badge badge-warning badge-sm gap-1"
                      >
                        <.icon name="hero-exclamation-triangle-mini" class="size-3" /> Not set
                      </span>
                    </div>
                  </div>

                  <div class="flex items-end gap-3">
                    <div class="form-control flex-1">
                      <label class="label" for="ollama_host_env">
                        <span class="label-text text-sm">Ollama Host</span>
                      </label>
                      <input
                        type="text"
                        name="settings[ollama_host_env]"
                        id="ollama_host_env"
                        value={@settings["ollama_host_env"]}
                        class="input input-bordered input-sm w-full font-mono text-xs"
                      />
                    </div>
                    <div class="pb-1">
                      <span
                        :if={@ollama_host_set}
                        class="badge badge-success badge-sm gap-1"
                      >
                        <.icon name="hero-check-circle-mini" class="size-3" /> Set
                      </span>
                      <span
                        :if={!@ollama_host_set}
                        class="badge badge-warning badge-sm gap-1"
                      >
                        <.icon name="hero-exclamation-triangle-mini" class="size-3" /> Not set
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Card 2: Performance --%>
          <div class="card bg-base-100 shadow-md animate-fade-up mt-8" style="animation-delay: 150ms">
            <div class="card-body">
              <h2 class="card-title text-lg">
                <.icon name="hero-bolt" class="size-5 text-primary" />
                Performance
              </h2>
              <p class="text-sm text-base-content/50 -mt-1">
                Tune concurrency and timeout parameters for wiki generation.
              </p>

              <div class="divider my-2"></div>

              <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
                <div class="form-control">
                  <label class="label" for="embedding_batch_size">
                    <span class="label-text text-sm">Embedding Batch Size</span>
                  </label>
                  <input
                    type="number"
                    name="settings[embedding_batch_size]"
                    id="embedding_batch_size"
                    value={@settings["embedding_batch_size"]}
                    min="1"
                    max="500"
                    class="input input-bordered input-sm w-full"
                  />
                  <label class="label">
                    <span class="label-text-alt text-base-content/30">1 – 500 chunks per batch</span>
                  </label>
                </div>

                <div class="form-control">
                  <label class="label" for="file_read_concurrency">
                    <span class="label-text text-sm">File Read Concurrency</span>
                  </label>
                  <input
                    type="number"
                    name="settings[file_read_concurrency]"
                    id="file_read_concurrency"
                    value={@settings["file_read_concurrency"]}
                    min="1"
                    max="100"
                    class="input input-bordered input-sm w-full"
                  />
                  <label class="label">
                    <span class="label-text-alt text-base-content/30">
                      1 – 100 concurrent reads
                    </span>
                  </label>
                </div>

                <div class="form-control">
                  <label class="label" for="wiki_page_timeout">
                    <span class="label-text text-sm">Page Timeout</span>
                  </label>
                  <div class="join w-full">
                    <input
                      type="number"
                      name="settings[wiki_page_timeout]"
                      id="wiki_page_timeout"
                      value={@settings["wiki_page_timeout"]}
                      min="10000"
                      max="600000"
                      step="1000"
                      class="input input-bordered input-sm join-item w-full"
                    />
                    <span class="btn btn-sm btn-disabled join-item border-base-content/20 bg-base-200 text-base-content/40 no-animation">
                      ms
                    </span>
                  </div>
                  <label class="label">
                    <span class="label-text-alt text-base-content/30">10s – 600s per wiki page</span>
                  </label>
                </div>
              </div>
            </div>
          </div>

          <%!-- Card 3: Storage --%>
          <div class="card bg-base-100 shadow-md animate-fade-up mt-8" style="animation-delay: 225ms">
            <div class="card-body">
              <h2 class="card-title text-lg">
                <.icon name="hero-folder-open" class="size-5 text-primary" />
                Storage
              </h2>
              <p class="text-sm text-base-content/50 -mt-1">
                Where cloned repositories are stored on disk.
              </p>

              <div class="divider my-2"></div>

              <div class="form-control">
                <label class="label" for="repos_path">
                  <span class="label-text text-sm">Repository Storage Path</span>
                </label>
                <input
                  type="text"
                  name="settings[repos_path]"
                  id="repos_path"
                  value={@settings["repos_path"]}
                  placeholder="~/.pearl/repos"
                  class="input input-bordered input-sm w-full font-mono text-xs"
                  phx-debounce="500"
                />
              </div>

              <div class="mt-3 rounded-lg bg-base-200/60 border border-base-content/5 px-4 py-3">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2 min-w-0">
                    <.icon name="hero-arrow-long-right" class="size-4 text-base-content/30 shrink-0" />
                    <span class="text-xs font-mono text-base-content/60 truncate">
                      {@resolved_path}
                    </span>
                  </div>
                  <span
                    :if={@path_exists}
                    class="badge badge-success badge-sm gap-1 shrink-0 ml-2"
                  >
                    <.icon name="hero-check-circle-mini" class="size-3" /> Exists
                  </span>
                  <span
                    :if={!@path_exists}
                    class="badge badge-warning badge-sm gap-1 shrink-0 ml-2"
                  >
                    <.icon name="hero-exclamation-triangle-mini" class="size-3" /> Not found
                  </span>
                </div>
              </div>
            </div>
          </div>

          <%!-- Footer --%>
          <div
            class="flex items-center justify-between animate-fade-up mt-8"
            style="animation-delay: 300ms"
          >
            <div>
              <p :if={@dirty} class="text-xs text-warning flex items-center gap-1.5">
                <.icon name="hero-exclamation-circle-mini" class="size-4" />
                You have unsaved changes.
              </p>
            </div>
            <button type="submit" class="btn btn-primary" disabled={!@dirty}>
              <.icon name="hero-check" class="size-4" />
              Save Settings
            </button>
          </div>
        </.form>

        <%!-- Re-index Modal --%>
        <dialog id="reindex-modal" class="modal">
          <div class="modal-box max-w-md">
            <h3 class="text-lg font-bold flex items-center gap-2">
              <.icon name="hero-exclamation-triangle" class="size-5 text-warning" />
              Re-indexing Required
            </h3>
            <p class="py-4 text-sm text-base-content/70">
              You changed the embedding provider or model. Existing embeddings are incompatible
              with the new configuration and repositories will need to be re-indexed for
              RAG search to work correctly.
            </p>

            <div class="divider my-0"></div>

            <div class="modal-action flex-col sm:flex-row gap-2">
              <button
                type="button"
                phx-click="save_and_reindex"
                class="btn btn-warning w-full sm:w-auto"
              >
                <.icon name="hero-arrow-path" class="size-4" />
                Save &amp; Re-index All
              </button>
              <button
                type="button"
                phx-click="save_without_reindex"
                class="btn btn-ghost w-full sm:w-auto"
              >
                Save Without Re-indexing
              </button>
            </div>

            <form method="dialog" class="absolute top-4 right-4">
              <button class="btn btn-ghost btn-sm btn-circle">
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </form>
          </div>
          <form method="dialog" class="modal-backdrop">
            <button>close</button>
          </form>
        </dialog>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"settings" => params}, socket) do
    settings = Map.merge(socket.assigns.settings, params)
    dirty = settings != socket.assigns.initial_settings

    {:noreply,
     assign(socket,
       settings: settings,
       dirty: dirty,
       embedding_changed:
         settings["embedding_provider"] != socket.assigns.initial_settings["embedding_provider"] or
           settings["embedding_model"] != socket.assigns.initial_settings["embedding_model"],
       openrouter_key_set: env_var_set?(settings["openrouter_api_key_env"]),
       ollama_host_set: env_var_set?(settings["ollama_host_env"]),
       resolved_path: Path.expand(settings["repos_path"]),
       path_exists: File.dir?(Path.expand(settings["repos_path"]))
     )}
  end

  def handle_event("save", %{"settings" => params}, socket) do
    settings = Map.merge(socket.assigns.settings, params)

    if settings["embedding_provider"] != socket.assigns.initial_settings["embedding_provider"] or
         settings["embedding_model"] != socket.assigns.initial_settings["embedding_model"] do
      {:noreply,
       socket
       |> assign(settings: settings)
       |> push_event("show-modal", %{id: "reindex-modal"})}
    else
      do_save(socket, settings)
    end
  end

  def handle_event("save_and_reindex", _params, socket) do
    {:noreply, socket} = do_save(socket, socket.assigns.settings)
    # Trigger re-index for all repos
    Task.Supervisor.start_child(Pearl.TaskSupervisor, fn ->
      Pearl.Repositories.list_repos()
      |> Enum.filter(&(&1.status == "ready"))
      |> Enum.each(fn repo ->
        Pearl.Rag.index_repo(repo)
      end)
    end)

    {:noreply, put_flash(socket, :info, "Settings saved. Re-indexing started in background.")}
  end

  def handle_event("save_without_reindex", _params, socket) do
    do_save(socket, socket.assigns.settings)
  end

  defp do_save(socket, settings) do
    Enum.each(settings, fn {key, value} ->
      if Map.has_key?(Settings.defaults(), key) do
        Settings.put(key, value)
      end
    end)

    {:noreply,
     socket
     |> assign(initial_settings: settings, dirty: false, embedding_changed: false)
     |> put_flash(:info, "Settings saved.")}
  end

  defp env_var_set?(env_var_name) when is_binary(env_var_name) do
    System.get_env(env_var_name) != nil
  end

  defp env_var_set?(_), do: false
end
```

**Step 4: Run tests**

Run: `mix test test/pearl_web/live/settings_live_test.exs -v`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add pearl/lib/pearl_web/live/settings_live.ex pearl/test/pearl_web/live/settings_live_test.exs
git commit -m "feat(settings): implement settings LiveView page"
```

---

## Task 8: Add JS Hook for Modal

**Files:**
- Modify: `pearl/assets/js/app.js` (add show-modal event listener)

The re-index modal is triggered via `push_event(socket, "show-modal", %{id: "reindex-modal"})`. We need a client-side hook to call `showModal()` on the dialog element.

**Step 1: Add the event listener**

In `pearl/assets/js/app.js`, add after the LiveSocket setup:

```javascript
// Handle show-modal events from LiveView
window.addEventListener("phx:show-modal", (e) => {
  const dialog = document.getElementById(e.detail.id)
  if (dialog) dialog.showModal()
})
```

**Step 2: Manual test**

Start the dev server (`mix phx.server`), navigate to `/settings`, change the embedding model, click Save. The re-index modal should appear.

**Step 3: Commit**

```bash
git add pearl/assets/js/app.js
git commit -m "feat(settings): add JS hook for re-index confirmation modal"
```

---

## Task 9: Update Repos Path Usage

**Files:**
- Search for uses of `Application.get_env(:pearl, :storage)[:repos_path]` or similar
- Update to use `Pearl.Config.repos_path()`

**Step 1: Find all repos_path references**

Search for `repos_path` in `lib/` to find all usages. The main user is likely `Pearl.Repositories`.

**Step 2: Update each reference**

Replace `Application.get_env(:pearl, :storage)[:repos_path]` with `Pearl.Config.repos_path()` wherever found.

**Step 3: Run all tests**

Run: `mix test -v`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add -u
git commit -m "refactor(config): update repos_path references to use Config module"
```

---

## Task 10: Final Integration Test + Cleanup

**Files:**
- Modify: `pearl/test/pearl_web/live/settings_live_test.exs` (add save integration test)

**Step 1: Add save integration test**

```elixir
# Add to settings_live_test.exs
describe "saving settings" do
  test "saves settings and shows flash", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")

    html =
      view
      |> form("form", settings: %{chat_model: "test/model-123"})
      |> render_submit()

    assert html =~ "Settings saved"
  end

  test "persists settings to database", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/settings")

    view
    |> form("form", settings: %{chat_model: "test/model-456"})
    |> render_submit()

    assert Settings.get("chat_model") == "test/model-456"
  end
end
```

**Step 2: Run the full test suite**

Run: `mix test -v`
Expected: All tests PASS

**Step 3: Run precommit checks**

Run: `mix precommit`
Expected: Compile (no warnings), format check, all tests PASS

**Step 4: Commit**

```bash
git add pearl/test/pearl_web/live/settings_live_test.exs
git commit -m "test(settings): add save integration tests"
```

---

## Task Summary

| # | Task | Files | Commits |
|---|------|-------|---------|
| 1 | Settings schema + migration | 3 new | `feat(settings): add settings schema and migration` |
| 2 | Settings context with ETS cache | 2 new | `feat(settings): add Settings context with ETS cache` |
| 3 | Initialize ETS on app start | 2 modified | `feat(settings): initialize ETS cache on application start` |
| 4 | Rewrite Pearl.Config | 2 modified | `feat(settings): rewrite Config to read from Settings context` |
| 5 | Update providers + contexts | 4 modified | `refactor(config): update providers and contexts to split config` |
| 6 | Clean up runtime.exs | 2 modified | `refactor(config): remove LLM env vars from runtime.exs` |
| 7 | Settings LiveView page | 2 modified | `feat(settings): implement settings LiveView page` |
| 8 | JS hook for modal | 1 modified | `feat(settings): add JS hook for re-index modal` |
| 9 | Update repos_path usage | varies | `refactor(config): update repos_path references` |
| 10 | Integration tests + cleanup | 1 modified | `test(settings): add save integration tests` |
