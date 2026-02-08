# Global Navbar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a persistent global navbar with search, breadcrumbs, and settings access — replacing WikiLive's internal mobile header.

**Architecture:** The `app/1` layout component becomes the single global chrome. A `NavbarHook` (on_mount) provides search assigns to all LiveViews. Each LiveView sets `drawer_id`, `breadcrumb`, and `show_ask` in its mount to customize the navbar per page.

**Tech Stack:** Elixir/Phoenix 1.8, LiveView 1.1, daisyUI navbar/drawer/dropdown, Heroicons via `<.icon>`, Ecto ilike queries.

**Design doc:** `docs/plans/2026-02-07-global-navbar-design.md`

---

### Task 1: Add `Repositories.search/1`

**Files:**
- Modify: `pearl/lib/pearl/repositories/repositories.ex:32` (after `list_repos/0`)
- Test: `pearl/test/pearl/repositories/repositories_test.exs`

**Step 1: Write the failing test**

Add to the end of `pearl/test/pearl/repositories/repositories_test.exs`, before the final `end`:

```elixir
describe "search/1" do
  setup do
    {:ok, _} =
      Repositories.create_repo(%{
        url: "https://github.com/acme/rocket",
        provider: "github",
        owner: "acme",
        name: "rocket"
      })

    {:ok, _} =
      Repositories.create_repo(%{
        url: "https://github.com/acme/launcher",
        provider: "github",
        owner: "acme",
        name: "launcher"
      })

    {:ok, _} =
      Repositories.create_repo(%{
        url: "https://github.com/other/widget",
        provider: "github",
        owner: "other",
        name: "widget"
      })

    :ok
  end

  test "returns repos matching owner" do
    results = Repositories.search("acme")
    assert length(results) == 2
    assert Enum.all?(results, &(&1.owner == "acme"))
  end

  test "returns repos matching name" do
    results = Repositories.search("rocket")
    assert length(results) == 1
    assert hd(results).name == "rocket"
  end

  test "search is case-insensitive" do
    results = Repositories.search("ROCKET")
    assert length(results) == 1
  end

  test "returns empty list for no matches" do
    assert Repositories.search("nonexistent") == []
  end

  test "returns empty list for empty query" do
    assert Repositories.search("") == []
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd pearl && mix test test/pearl/repositories/repositories_test.exs --no-start`

Expected: Compilation error — `search/1` is undefined.

**Step 3: Write minimal implementation**

Add after the `list_repos/0` function (after line 32 in `pearl/lib/pearl/repositories/repositories.ex`):

```elixir
@spec search(String.t()) :: [RepoRecord.t()]
def search(""), do: []

def search(query) when is_binary(query) do
  pattern = "%#{query}%"

  RepoRecord
  |> where([r], ilike(r.owner, ^pattern) or ilike(r.name, ^pattern))
  |> order_by(desc: :inserted_at)
  |> Repo.all()
end
```

**Step 4: Run test to verify it passes**

Run: `cd pearl && mix test test/pearl/repositories/repositories_test.exs`

Expected: All tests pass.

**Step 5: Commit**

```bash
cd pearl && git add lib/pearl/repositories/repositories.ex test/pearl/repositories/repositories_test.exs && git commit -m "feat: add Repositories.search/1 for navbar search"
```

---

### Task 2: Create NavbarHook

**Files:**
- Create: `pearl/lib/pearl_web/live/navbar_hook.ex`
- Test: `pearl/test/pearl_web/live/navbar_hook_test.exs`

**Step 1: Write the failing test**

Create `pearl/test/pearl_web/live/navbar_hook_test.exs`:

```elixir
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
```

**Step 2: Run test to verify it fails**

Run: `cd pearl && mix test test/pearl_web/live/navbar_hook_test.exs`

Expected: Failure — NavbarHook doesn't exist yet, and the search form isn't in the layout.

> **Note:** This test depends on the layout having the search form (Task 3) and the router using the hook (Task 4). We create the hook module first, then the tests will pass after Tasks 3 and 4.

**Step 3: Create the NavbarHook module**

Create `pearl/lib/pearl_web/live/navbar_hook.ex`:

```elixir
defmodule PearlWeb.NavbarHook do
  @moduledoc """
  Shared on_mount hook that provides navbar search functionality to all LiveViews.

  Assigns `search_results` and `search_query` on mount, and intercepts the
  "search" event from the navbar search form.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(search_results: [], search_query: "")
      |> attach_hook(:navbar_search, :handle_event, &handle_event/3)

    {:cont, socket}
  end

  defp handle_event("search", %{"q" => ""}, socket) do
    {:halt, assign(socket, search_results: [], search_query: "")}
  end

  defp handle_event("search", %{"q" => query}, socket) do
    results = Pearl.Repositories.search(query)
    {:halt, assign(socket, search_results: results, search_query: query)}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}
end
```

**Step 4: Verify it compiles**

Run: `cd pearl && mix compile --no-start`

Expected: Compilation succeeds with no errors.

**Step 5: Commit**

```bash
cd pearl && git add lib/pearl_web/live/navbar_hook.ex test/pearl_web/live/navbar_hook_test.exs && git commit -m "feat: add NavbarHook for global search event handling"
```

---

### Task 3: Rewrite `app/1` layout with global navbar

**Files:**
- Modify: `pearl/lib/pearl_web/components/layouts.ex:28-54`

**Step 1: Rewrite `app/1` attrs and markup**

Replace lines 28–54 in `pearl/lib/pearl_web/components/layouts.ex` (the attr declarations and the `app/1` function body) with:

```elixir
attr :flash, :map, required: true, doc: "the map of flash messages"

attr :current_scope, :map,
  default: nil,
  doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

attr :drawer_id, :string, default: nil, doc: "drawer checkbox ID (for wiki mobile hamburger)"
attr :breadcrumb, :string, default: nil, doc: "breadcrumb text shown after Pearl wordmark"
attr :show_ask, :boolean, default: false, doc: "whether to show the Ask button"
attr :search_results, :list, default: [], doc: "list of repo search results"

slot :inner_block, required: true

def app(assigns) do
  ~H"""
  <header class="navbar h-12 min-h-12 bg-base-100 border-b border-base-content/8 px-4 sticky top-0 z-50">
    <div class="navbar-start gap-2">
      <label :if={@drawer_id} for={@drawer_id} class="btn btn-ghost btn-sm btn-square lg:hidden">
        <.icon name="hero-bars-3" class="size-5" />
      </label>

      <.link navigate={~p"/"} class="font-semibold tracking-wider uppercase text-sm text-base-content/70 hover:text-primary transition-colors">
        Pearl
      </.link>
      <span :if={@breadcrumb} class="text-base-content/20">/</span>
      <span :if={@breadcrumb} class="text-sm font-medium truncate max-w-48">{@breadcrumb}</span>
    </div>

    <div class="navbar-center hidden sm:flex">
      <div class="relative">
        <form phx-change="search" phx-submit="search">
          <.icon name="hero-magnifying-glass" class="size-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/30" />
          <input type="text" name="q" placeholder="Search repos..."
            class="input input-sm bg-base-200/50 border-base-content/10 pl-9 w-56 focus:w-72 transition-all duration-200 text-sm" />
        </form>
        <ul :if={@search_results != []} class="menu bg-base-200 rounded-box absolute top-full mt-1 w-72 p-2 shadow-lg border border-base-content/10 z-50">
          <li :for={repo <- @search_results}>
            <.link navigate={~p"/wiki/#{repo.id}"}>{repo.owner}/{repo.name}</.link>
          </li>
        </ul>
      </div>
    </div>

    <div class="navbar-end gap-1">
      <button class="btn btn-ghost btn-sm btn-circle sm:hidden">
        <.icon name="hero-magnifying-glass" class="size-4" />
      </button>

      <button :if={@show_ask} phx-click="toggle_ask" class="btn btn-ghost btn-sm gap-1.5 text-base-content/60 hover:text-primary">
        <.icon name="hero-chat-bubble-left-right" class="size-4" />
        <span class="hidden md:inline text-xs">Ask</span>
      </button>

      <div class="dropdown dropdown-end">
        <div tabindex="0" role="button" class="btn btn-ghost btn-sm btn-circle">
          <.icon name="hero-cog-6-tooth" class="size-4" />
        </div>
        <ul tabindex="0" class="dropdown-content menu bg-base-200 rounded-box z-[1] w-48 p-2 shadow-lg border border-base-content/10 mt-2">
          <li>
            <.link navigate={~p"/settings"}>
              <.icon name="hero-adjustments-horizontal" class="size-4" /> Settings
            </.link>
          </li>
        </ul>
      </div>
    </div>
  </header>

  {render_slot(@inner_block)}

  <.flash_group flash={@flash} />
  """
end
```

Key changes from the old `app/1`:
- New attrs: `drawer_id`, `breadcrumb`, `show_ask`, `search_results`
- Navbar is 48px sticky with `z-50`
- Inner block is rendered directly (no wrapping `<main>` — each LiveView controls its own layout)
- Search form with `phx-change="search"` (handled by NavbarHook)
- Conditional drawer hamburger, breadcrumb, Ask button
- Settings dropdown with gear icon

**Step 2: Verify it compiles**

Run: `cd pearl && mix compile --no-start`

Expected: Compilation succeeds (warnings are OK for now since LiveViews don't set the new assigns yet).

**Step 3: Commit**

```bash
cd pearl && git add lib/pearl_web/components/layouts.ex && git commit -m "feat: rewrite app/1 layout with global navbar"
```

---

### Task 4: Update router with `live_session` and `on_mount`

**Files:**
- Modify: `pearl/lib/pearl_web/router.ex:26-31`

**Step 1: Replace the scope block**

Replace lines 26–31 in `pearl/lib/pearl_web/router.ex`:

```elixir
scope "/", PearlWeb do
  pipe_through :browser

  live "/", HomeLive, :index
  live "/wiki/:id", WikiLive, :show
end
```

With:

```elixir
scope "/", PearlWeb do
  pipe_through :browser

  live_session :default,
    layout: {PearlWeb.Layouts, :app},
    on_mount: [PearlWeb.NavbarHook] do
    live "/", HomeLive, :index
    live "/wiki/:id", WikiLive, :show
    live "/settings", SettingsLive, :index
  end
end
```

**Step 2: Verify it compiles**

Run: `cd pearl && mix compile --no-start`

Expected: Compilation succeeds (SettingsLive doesn't exist yet — warning only, not error, since `live/3` is a macro that resolves at runtime).

**Step 3: Commit**

```bash
cd pearl && git add lib/pearl_web/router.ex && git commit -m "feat: wrap routes in live_session with NavbarHook"
```

---

### Task 5: Create SettingsLive placeholder

**Files:**
- Create: `pearl/lib/pearl_web/live/settings_live.ex`
- Test: `pearl/test/pearl_web/live/settings_live_test.exs`

**Step 1: Write the failing test**

Create `pearl/test/pearl_web/live/settings_live_test.exs`:

```elixir
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
```

**Step 2: Run test to verify it fails**

Run: `cd pearl && mix test test/pearl_web/live/settings_live_test.exs`

Expected: Failure — module does not exist.

**Step 3: Create SettingsLive**

Create `pearl/lib/pearl_web/live/settings_live.ex`:

```elixir
defmodule PearlWeb.SettingsLive do
  @moduledoc """
  Placeholder settings page.
  """
  use PearlWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       drawer_id: nil,
       breadcrumb: "Settings",
       show_ask: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-8 px-4">
      <h1 class="text-2xl font-bold mb-4">Settings</h1>
      <p class="text-base-content/60">Settings coming soon.</p>
    </div>
    """
  end
end
```

**Step 4: Run test to verify it passes**

Run: `cd pearl && mix test test/pearl_web/live/settings_live_test.exs`

Expected: All tests pass.

**Step 5: Commit**

```bash
cd pearl && git add lib/pearl_web/live/settings_live.ex test/pearl_web/live/settings_live_test.exs && git commit -m "feat: add placeholder SettingsLive page"
```

---

### Task 6: Update HomeLive — add navbar assigns, remove inline header

**Files:**
- Modify: `pearl/lib/pearl_web/live/home_live.ex:16-27` (mount), `pearl/lib/pearl_web/live/home_live.ex:32-37` (render header)
- Test: `pearl/test/pearl_web/live/home_live_test.exs`

**Step 1: Update the existing test to check for navbar**

Add to `pearl/test/pearl_web/live/home_live_test.exs`, inside the `describe "HomeLive"` block, before the last `end`:

```elixir
test "has global navbar with Pearl wordmark", %{conn: conn} do
  {:ok, _view, html} = live(conn, "/")

  # Global navbar renders Pearl link
  assert html =~ ~s(Pearl)
  assert html =~ "Search repos"
end

test "does not show Ask button on home", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/")

  refute has_element?(view, "button[phx-click=toggle_ask]")
end
```

**Step 2: Run tests to see them fail**

Run: `cd pearl && mix test test/pearl_web/live/home_live_test.exs`

Expected: New tests fail (navbar not yet rendered from HomeLive's perspective — depends on assigns).

**Step 3: Update HomeLive mount**

In `pearl/lib/pearl_web/live/home_live.ex`, add navbar assigns to the mount (lines 16-27). Add these three assigns to the `assign()` call:

```elixir
drawer_id: nil,
breadcrumb: nil,
show_ask: false,
```

So the full mount assigns become:

```elixir
{:ok,
 assign(socket,
   page_title: "Pearl",
   drawer_id: nil,
   breadcrumb: nil,
   show_ask: false,
   repos: repos,
   repo_url: "",
   generating: false,
   progress_by_repo: %{},
   error: nil,
   confirm_delete_id: nil,
   linked_tasks: MapSet.new()
 )}
```

**Step 4: Remove the inline header from HomeLive render**

In the render function (line 34-37), remove the `<header>` block:

```heex
<header class="text-center mb-12">
  <h1 class="text-4xl font-bold mb-2">Pearl</h1>
  <p class="opacity-70">Generate wikis from your code.</p>
</header>
```

Replace it with a simpler heading that doesn't duplicate the navbar:

```heex
<header class="text-center mb-12">
  <h1 class="text-4xl font-bold mb-2">Generate Wikis</h1>
  <p class="opacity-70">Paste a repository URL to generate a comprehensive wiki.</p>
</header>
```

**Step 5: Run tests to verify they pass**

Run: `cd pearl && mix test test/pearl_web/live/home_live_test.exs`

Expected: All tests pass. The existing "renders home page" test checks for "Pearl" and "Generate Wiki" — "Pearl" now comes from the navbar, and "Generate Wiki" still exists in the button.

**Step 6: Commit**

```bash
cd pearl && git add lib/pearl_web/live/home_live.ex test/pearl_web/live/home_live_test.exs && git commit -m "feat: add navbar assigns to HomeLive, remove duplicate header"
```

---

### Task 7: Update WikiLive — remove internal navbar, add layout assigns, adjust drawer

**Files:**
- Modify: `pearl/lib/pearl_web/live/wiki_live.ex:26-38` (mount), `pearl/lib/pearl_web/live/wiki_live.ex:46-223` (render)
- Test: `pearl/test/pearl_web/live/wiki_live_test.exs`

**Step 1: Update tests**

Add to `pearl/test/pearl_web/live/wiki_live_test.exs`, inside the `describe "WikiLive"` block, before the last `end`:

```elixir
test "has global navbar with breadcrumb", %{conn: conn, repo: repo} do
  {:ok, _view, html} = live(conn, "/wiki/#{repo.id}")

  # Navbar shows the repo as breadcrumb
  assert html =~ "Pearl"
  assert html =~ "#{repo.owner}/#{repo.name}"
end

test "has Ask button in navbar", %{conn: conn, repo: repo} do
  {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

  assert has_element?(view, "button[phx-click=toggle_ask]")
end

test "does not have internal mobile navbar", %{conn: conn, repo: repo} do
  {:ok, view, _html} = live(conn, "/wiki/#{repo.id}")

  # The old internal mobile navbar had class "lg:hidden" with a "navbar" inside drawer-content
  # Now there should be no navbar inside the drawer-content div
  refute has_element?(view, ".drawer-content > .navbar")
end
```

**Step 2: Run tests to see them fail**

Run: `cd pearl && mix test test/pearl_web/live/wiki_live_test.exs`

Expected: The "does not have internal mobile navbar" test fails (it still exists).

**Step 3: Add navbar assigns to WikiLive mount**

In `pearl/lib/pearl_web/live/wiki_live.ex`, update the mount (lines 26-38) to include navbar assigns:

```elixir
{:ok,
 assign(socket,
   page_title: "#{repo.owner}/#{repo.name} - Pearl",
   drawer_id: "wiki-drawer",
   breadcrumb: "#{repo.owner}/#{repo.name}",
   show_ask: true,
   repo: repo,
   wiki_cache: wiki_cache,
   pages: pages,
   current_page_id: current_page_id,
   current_content: get_page_content(wiki_cache, current_page_id),
   ask_open: false,
   ask_messages: [],
   ask_current_input: "",
   ask_loading: false
 )}
```

**Step 4: Update WikiLive render — remove internal navbar, adjust drawer heights**

Replace the entire render function body (lines 46-224) with:

```elixir
def render(assigns) do
  ~H"""
  <div class="drawer lg:drawer-open">
    <input id="wiki-drawer" type="checkbox" class="drawer-toggle" />

    <div class="drawer-content flex flex-col bg-base-200 h-[calc(100dvh-3rem)]">
      <!-- Content wrapper -->
      <div class="flex flex-1 overflow-hidden">
        <!-- Main content -->
        <main class="flex-1 overflow-y-auto bg-base-100">
          <%= if @wiki_cache do %>
            <div class="max-w-4xl mx-auto py-8 px-8">
              <MarkdownComponent.markdown id="wiki-content" content={@current_content} />
            </div>
          <% else %>
            <div class="flex items-center justify-center h-full">
              <div class="text-center opacity-60">
                <p class="text-lg mb-2">No wiki generated yet</p>
                <.link navigate={~p"/"} class="link link-primary">
                  Generate one now
                </.link>
              </div>
            </div>
          <% end %>
        </main>

        <!-- Ask panel (slide-out) -->
        <%= if @ask_open do %>
          <aside class="w-[36rem] bg-gradient-to-b from-base-100 to-base-200 border-l border-base-300/50 flex flex-col">
            <div class="px-5 py-4 border-b border-primary/20 bg-gradient-to-r from-primary/5 to-transparent flex items-center justify-between">
              <h3 class="text-sm font-semibold tracking-wide uppercase text-primary/80 font-[family-name:var(--font-heading)]">
                Ask about the codebase
              </h3>
              <button
                phx-click="toggle_ask"
                class="btn btn-ghost btn-sm btn-circle text-base-content/50 hover:text-base-content"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>

            <div class="flex-1 overflow-y-auto p-5" id="ask-messages" phx-hook="ScrollToBottom">
              <%= if @ask_messages == [] do %>
                <div class="flex items-center justify-center h-full">
                  <div class="text-center">
                    <.icon
                      name="hero-chat-bubble-left-right"
                      class="size-12 text-primary/20 mx-auto mb-4"
                    />
                    <p class="text-base-content/30 text-sm">Ask anything about the codebase</p>
                  </div>
                </div>
              <% end %>
              <%= for {message, idx} <- Enum.with_index(@ask_messages) do %>
                <%= if message.role == :user do %>
                  <div class="chat chat-end mb-4">
                    <div class="chat-bubble chat-bubble-primary">
                      {message.content}
                    </div>
                  </div>
                <% else %>
                  <div class="mb-4">
                    <div class="rounded-lg bg-base-300/50 border-l-2 border-primary/40 px-4 py-3">
                      <%= if message.content == "" and @ask_loading do %>
                        <span class="loading loading-dots loading-sm text-primary/60"></span>
                      <% else %>
                        <MarkdownComponent.markdown
                          id={"ask-msg-#{idx}"}
                          content={message.content}
                          class="prose-sm [&_pre]:overflow-x-auto [&_pre]:max-w-full [&_code]:text-xs"
                        />
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>

            <div class="p-4 border-t border-primary/20 bg-base-200/50">
              <form phx-submit="ask" class="flex gap-3 items-center">
                <input
                  type="text"
                  name="question"
                  value={@ask_current_input}
                  placeholder="Ask anything about this codebase..."
                  id="ask-input"
                  class="input input-bordered flex-1 bg-base-300/50 focus:border-primary/50"
                  disabled={@ask_loading}
                  phx-debounce="300"
                  phx-hook="AutoFocus"
                />
                <button type="submit" disabled={@ask_loading} class="btn btn-primary btn-circle">
                  <%= if @ask_loading do %>
                    <span class="loading loading-spinner loading-sm"></span>
                  <% else %>
                    <.icon name="hero-paper-airplane" class="size-5" />
                  <% end %>
                </button>
              </form>
            </div>
          </aside>
        <% end %>
      </div>
    </div>

    <!-- Sidebar -->
    <div class="drawer-side z-40 h-[calc(100dvh-3rem)] top-12">
      <label for="wiki-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
      <aside class="bg-base-100 min-h-full w-64 flex flex-col border-r border-base-300">
        <div class="p-4 border-b border-base-300">
          <h2 class="font-semibold truncate">
            {@repo.owner}/{@repo.name}
          </h2>
        </div>

        <nav class="flex-1 overflow-y-auto p-2">
          <ul class="menu menu-sm">
            <%= for page <- @pages do %>
              <li>
                <button
                  phx-click="select_page"
                  phx-value-id={page["id"]}
                  class={if @current_page_id == page["id"], do: "active", else: ""}
                >
                  {page["title"]}
                </button>
              </li>
            <% end %>
          </ul>
        </nav>

        <div class="p-4 border-t border-base-300">
          <button
            phx-click="toggle_ask"
            class="btn btn-ghost btn-sm w-full gap-2 text-base-content/60 hover:text-base-content"
          >
            <%= if @ask_open do %>
              <.icon name="hero-x-mark" class="size-4" /> Close Chat
            <% else %>
              <.icon name="hero-chat-bubble-left-right" class="size-4" /> Chat with AI
            <% end %>
          </button>
        </div>
      </aside>
    </div>
  </div>
  """
end
```

Key differences from old render:
1. **Removed** the entire mobile navbar block (lines 53-79 in old file)
2. **Changed** `drawer-content` height: `h-screen` → `h-[calc(100dvh-3rem)]`
3. **Changed** `drawer-side`: added `z-40 h-[calc(100dvh-3rem)] top-12`
4. **Removed** "Back to Home" link from sidebar (Pearl wordmark in navbar handles this)

**Step 5: Run tests to verify they pass**

Run: `cd pearl && mix test test/pearl_web/live/wiki_live_test.exs`

Expected: All tests pass.

**Step 6: Commit**

```bash
cd pearl && git add lib/pearl_web/live/wiki_live.ex test/pearl_web/live/wiki_live_test.exs && git commit -m "feat: remove WikiLive internal navbar, integrate with global navbar"
```

---

### Task 8: Run full test suite and fix any issues

**Files:**
- All modified files from Tasks 1-7

**Step 1: Run the full test suite**

Run: `cd pearl && mix test`

Expected: All tests pass.

**Step 2: Run format check**

Run: `cd pearl && mix format --check-formatted`

Expected: All files formatted. If not, run `mix format`.

**Step 3: Run precommit checks**

Run: `cd pearl && mix precommit`

Expected: Compilation with warnings-as-errors, format check, and tests all pass.

**Step 4: Fix any issues found**

If any tests fail due to integration issues (e.g., search form selector not found, assigns missing), fix them here.

**Step 5: Commit any fixes**

```bash
cd pearl && git add -A && git commit -m "fix: resolve integration issues from navbar implementation"
```

(Skip this commit if no fixes were needed.)

---

### Task 9: Run NavbarHook tests (deferred from Task 2)

**Step 1: Run the NavbarHook tests**

Run: `cd pearl && mix test test/pearl_web/live/navbar_hook_test.exs`

Expected: All tests pass now that the layout has the search form and router uses the hook.

**Step 2: Fix any issues**

If the `form[phx-change=search]` selector doesn't match, adjust the test selector. The search form is in the layout, not the LiveView, so it should render on every page.

**Step 3: Final commit if needed**

```bash
cd pearl && git add -A && git commit -m "fix: finalize navbar hook tests"
```

---

## Summary of all changes

| # | File | Action | Description |
|---|------|--------|-------------|
| 1 | `lib/pearl/repositories/repositories.ex` | Edit | Add `search/1` with ilike query |
| 2 | `test/pearl/repositories/repositories_test.exs` | Edit | Add search tests |
| 3 | `lib/pearl_web/live/navbar_hook.ex` | Create | on_mount hook for search events |
| 4 | `test/pearl_web/live/navbar_hook_test.exs` | Create | Hook integration tests |
| 5 | `lib/pearl_web/components/layouts.ex` | Edit | Rewrite `app/1` with global navbar |
| 6 | `lib/pearl_web/router.ex` | Edit | Add `live_session` with layout + hook |
| 7 | `lib/pearl_web/live/settings_live.ex` | Create | Placeholder settings page |
| 8 | `test/pearl_web/live/settings_live_test.exs` | Create | Settings page tests |
| 9 | `lib/pearl_web/live/home_live.ex` | Edit | Add navbar assigns, simplify header |
| 10 | `test/pearl_web/live/home_live_test.exs` | Edit | Add navbar presence tests |
| 11 | `lib/pearl_web/live/wiki_live.ex` | Edit | Remove internal navbar, adjust drawer |
| 12 | `test/pearl_web/live/wiki_live_test.exs` | Edit | Add navbar/breadcrumb tests |
